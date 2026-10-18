#!/usr/bin/env python3
"""Wasla Institution Admin Desktop App.

The service-role key is read from the environment and is never hard-coded.
Run after applying the companion SQL migration:
  export SUPABASE_URL='https://YOUR_PROJECT.supabase.co'
  export SUPABASE_SERVICE_ROLE_KEY='YOUR_SERVICE_ROLE_KEY'
  python3 tools/institution_admin_app.py
"""
from __future__ import annotations

import os
import re
import secrets
import string
import tkinter as tk
from tkinter import messagebox, ttk
from typing import Any

import requests


TYPE_OPTIONS = {
    "مطعم صغير": "restaurant",
    "بقالة": "grocery",
    "سوبر ماركت": "supermarket",
    "مخبز": "bakery",
    "حلويات": "pastry_shop",
    "فندق": "hotel",
    "قاعة أفراح": "wedding_hall",
}
STATUS_OPTIONS = {
    "قيد المراجعة": "pending",
    "معتمد": "approved",
}


class SupabaseAdmin:
    def __init__(self, url: str, service_role_key: str) -> None:
        self.url = url.rstrip("/")
        self.key = service_role_key
        self.headers = {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Content-Type": "application/json",
        }

    def create_auth_user(self, email: str, password: str, name: str) -> dict[str, Any]:
        response = requests.post(
            f"{self.url}/auth/v1/admin/users",
            headers=self.headers,
            json={
                "email": email,
                "password": password,
                "email_confirm": True,
                "user_metadata": {
                    "name": name,
                    "role": "institution",
                    "desktop_admin_fixture": True,
                },
            },
            timeout=30,
        )
        if response.status_code not in (200, 201):
            raise RuntimeError(self._error(response, "تعذر إنشاء حساب Auth"))
        return response.json()

    def delete_auth_user(self, user_id: str) -> None:
        # Best-effort rollback if the database RPC fails.
        requests.delete(
            f"{self.url}/auth/v1/admin/users/{user_id}",
            headers=self.headers,
            timeout=30,
        )

    def create_institution(self, payload: dict[str, Any]) -> dict[str, Any]:
        response = requests.post(
            f"{self.url}/rest/v1/rpc/admin_create_institution",
            headers=self.headers,
            json=payload,
            timeout=30,
        )
        if response.status_code != 200:
            raise RuntimeError(self._error(response, "تعذر حفظ المؤسسة"))
        data = response.json()
        if not isinstance(data, dict):
            raise RuntimeError("استجابة غير صالحة من الخادم")
        return data

    @staticmethod
    def _error(response: requests.Response, fallback: str) -> str:
        try:
            body = response.json()
            detail = body.get("message") or body.get("error_description") or body.get("hint")
            if detail:
                return f"{fallback}: {detail}"
        except ValueError:
            pass
        return f"{fallback} (HTTP {response.status_code})"


def generate_password(length: int = 16) -> str:
    alphabet = string.ascii_letters + string.digits + "!@#$%"
    return "".join(secrets.choice(alphabet) for _ in range(length))


class InstitutionAdminApp(tk.Tk):
    def __init__(self, api: SupabaseAdmin) -> None:
        super().__init__()
        self.api = api
        self.title("إضافة مؤسسة - وصلة")
        self.geometry("680x720")
        self.minsize(620, 680)
        self.configure(padx=18, pady=18)
        self.vars: dict[str, tk.StringVar] = {}
        self._build_ui()

    def _build_ui(self) -> None:
        title = ttk.Label(self, text="إضافة مؤسسة جديدة", font=("TkDefaultFont", 18, "bold"))
        title.pack(anchor="e", pady=(0, 4))
        ttk.Label(
            self,
            text="سيتم إنشاء حساب دخول للمؤسسة وOTP ثانٍ مشفّر داخل قاعدة البيانات.",
        ).pack(anchor="e", pady=(0, 16))

        form = ttk.Frame(self)
        form.pack(fill="x")
        form.columnconfigure(1, weight=1)

        fields = [
            ("name", "اسم المؤسسة *", ""),
            ("email", "البريد الإلكتروني *", ""),
            ("phone", "الهاتف", ""),
            ("city", "المدينة", "القاهرة"),
            ("address", "العنوان", ""),
            ("description", "الوصف", ""),
            ("password", "كلمة مرور الدخول *", ""),
            ("otp", "OTP الثاني (6 أرقام) *", ""),
        ]
        for row, (key, label, default) in enumerate(fields):
            self.vars[key] = tk.StringVar(value=default)
            ttk.Label(form, text=label).grid(row=row, column=0, sticky="e", padx=(0, 10), pady=6)
            entry = ttk.Entry(form, textvariable=self.vars[key], show="•" if key == "password" else "")
            entry.grid(row=row, column=1, sticky="ew", pady=6)
            if key == "password":
                ttk.Button(form, text="توليد", command=self._generate_password).grid(
                    row=row, column=2, padx=(8, 0), pady=6
                )

        row = len(fields)
        ttk.Label(form, text="نوع المؤسسة *").grid(row=row, column=0, sticky="e", padx=(0, 10), pady=6)
        self.type_var = tk.StringVar(value="بقالة")
        ttk.Combobox(
            form,
            textvariable=self.type_var,
            values=list(TYPE_OPTIONS),
            state="readonly",
        ).grid(row=row, column=1, sticky="ew", pady=6)

        row += 1
        ttk.Label(form, text="الحالة").grid(row=row, column=0, sticky="e", padx=(0, 10), pady=6)
        self.status_var = tk.StringVar(value="قيد المراجعة")
        ttk.Combobox(
            form,
            textvariable=self.status_var,
            values=list(STATUS_OPTIONS),
            state="readonly",
        ).grid(row=row, column=1, sticky="ew", pady=6)

        self.verified_var = tk.BooleanVar(value=False)
        row += 1
        ttk.Checkbutton(form, text="تفعيل التحقق للمؤسسة", variable=self.verified_var).grid(
            row=row, column=1, sticky="e", pady=8
        )

        ttk.Separator(self).pack(fill="x", pady=18)
        self.create_button = ttk.Button(self, text="إنشاء المؤسسة", command=self._submit)
        self.create_button.pack(anchor="center", ipadx=18, ipady=5)
        self.status_label = ttk.Label(self, text="جاهز")
        self.status_label.pack(anchor="e", pady=(14, 0))

    def _generate_password(self) -> None:
        self.vars["password"].set(generate_password())

    def _submit(self) -> None:
        values = {key: var.get().strip() for key, var in self.vars.items()}
        if not values["name"] or not values["email"] or not values["password"] or not values["otp"]:
            messagebox.showerror("بيانات ناقصة", "املأ الحقول الإلزامية أولًا.")
            return
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", values["email"]):
            messagebox.showerror("بريد غير صحيح", "أدخل بريدًا إلكترونيًا صحيحًا.")
            return
        if len(values["password"]) < 8:
            messagebox.showerror("كلمة المرور ضعيفة", "يجب أن تكون 8 أحرف على الأقل.")
            return
        if not re.fullmatch(r"\d{6}", values["otp"]):
            messagebox.showerror("OTP غير صحيح", "OTP يجب أن يتكون من 6 أرقام.")
            return

        self.create_button.configure(state="disabled")
        self.status_label.configure(text="جاري إنشاء الحساب والمؤسسة...")
        self.update_idletasks()
        auth_user_id: str | None = None
        try:
            auth_user = self.api.create_auth_user(values["email"], values["password"], values["name"])
            auth_user_id = str(auth_user.get("id") or auth_user.get("user", {}).get("id"))
            if not auth_user_id or auth_user_id == "None":
                raise RuntimeError("لم يرجع الخادم معرف حساب Auth")

            result = self.api.create_institution(
                {
                    "p_user_id": auth_user_id,
                    "p_name": values["name"],
                    "p_email": values["email"],
                    "p_phone": values["phone"] or None,
                    "p_institution_type": TYPE_OPTIONS[self.type_var.get()],
                    "p_city": values["city"] or None,
                    "p_address": values["address"] or None,
                    "p_description": values["description"] or None,
                    "p_status": STATUS_OPTIONS[self.status_var.get()],
                    "p_is_verified": bool(self.verified_var.get()),
                    "p_login_otp": values["otp"],
                }
            )
            institution_id = result.get("institution_id", "غير متاح")
            self.status_label.configure(text="تم الإنشاء بنجاح")
            messagebox.showinfo(
                "تم إنشاء المؤسسة",
                f"المعرف: {institution_id}\n\n"
                f"البريد: {values['email']}\n"
                f"كلمة المرور: {values['password']}\n"
                f"OTP: {values['otp']}\n\n"
                "احتفظ بهذه البيانات بأمان.",
            )
            self._clear_form()
        except Exception as exc:  # noqa: BLE001 - user-facing desktop error
            if auth_user_id:
                self.api.delete_auth_user(auth_user_id)
            self.status_label.configure(text="فشل الإنشاء")
            messagebox.showerror("فشل الإنشاء", str(exc))
        finally:
            self.create_button.configure(state="normal")

    def _clear_form(self) -> None:
        for key, var in self.vars.items():
            var.set("القاهرة" if key == "city" else "")
        self.type_var.set("بقالة")
        self.status_var.set("قيد المراجعة")
        self.verified_var.set(False)


def main() -> None:
    url = os.getenv("SUPABASE_URL", "").strip()
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror(
            "إعداد ناقص",
            "عرّف SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY في متغيرات البيئة أولًا.",
        )
        root.destroy()
        raise SystemExit(2)
    InstitutionAdminApp(SupabaseAdmin(url, key)).mainloop()


if __name__ == "__main__":
    main()
