"""
load_test.py
اختبار حمل بسيط - يحتاج فقط: pip install requests

تشغيل:
    python load_test.py
"""

import time
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

# ==================== إعدادات ====================
SUPABASE_URL = "https://gsrhoqdtcyfdmvgahqvl.supabase.co"
ANON_KEY = "sb_publishable_dVIM-E6QaOFvZIgJfhgJVg_Dqj8OmbH"  # anon/publishable key

CONCURRENT_USERS = 50      # عدد المستخدمين المتزامنين - جرّب 10 ثم 50 ثم 200
REQUESTS_PER_USER = 5       # كل مستخدم هيبعت كام طلب
TIMEOUT_SECONDS = 15
# ===================================================

HEADERS = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
}

ENDPOINT = f"{SUPABASE_URL}/rest/v1/food_offers?select=*&status=eq.available&limit=20"


def make_request():
    start = time.perf_counter()
    try:
        response = requests.get(ENDPOINT, headers=HEADERS, timeout=TIMEOUT_SECONDS)
        elapsed_ms = (time.perf_counter() - start) * 1000
        return {
            "success": response.status_code == 200,
            "status": response.status_code,
            "ms": elapsed_ms,
        }
    except requests.exceptions.RequestException as error:
        elapsed_ms = (time.perf_counter() - start) * 1000
        return {
            "success": False,
            "status": f"error: {type(error).__name__}",
            "ms": elapsed_ms,
        }


def simulate_user():
    return [make_request() for _ in range(REQUESTS_PER_USER)]


def main():
    print(f"بدء الاختبار: {CONCURRENT_USERS} مستخدم متزامن، كل واحد هيبعت {REQUESTS_PER_USER} طلبات...")
    print(f"إجمالي الطلبات المتوقعة: {CONCURRENT_USERS * REQUESTS_PER_USER}\n")

    all_results = []
    test_start = time.perf_counter()

    with ThreadPoolExecutor(max_workers=CONCURRENT_USERS) as executor:
        futures = [executor.submit(simulate_user) for _ in range(CONCURRENT_USERS)]
        for future in as_completed(futures):
            all_results.extend(future.result())

    total_time = time.perf_counter() - test_start

    total = len(all_results)
    succeeded = sum(1 for r in all_results if r["success"])
    failed = total - succeeded
    times = sorted(r["ms"] for r in all_results)
    avg_ms = statistics.mean(times)
    max_ms = max(times)
    p95_index = max(0, int(len(times) * 0.95) - 1)
    p95_ms = times[p95_index]

    print("===================== النتيجة =====================")
    print(f"إجمالي الطلبات:        {total}")
    print(f"نجحت:                  {succeeded}")
    print(f"فشلت:                  {failed}")
    print(f"متوسط زمن الاستجابة:    {avg_ms:.0f} ms")
    print(f"أسوأ زمن استجابة:       {max_ms:.0f} ms")
    print(f"P95 (95% من الطلبات):   {p95_ms:.0f} ms")
    print(f"الوقت الكلي للاختبار:   {total_time:.2f} ثانية")
    print("====================================================")

    fail_rate = failed / total if total else 0
    if fail_rate > 0.05:
        print(f"⚠️  نسبة الفشل {fail_rate:.0%} أعلى من 5% — السيرفر بدأ يتعب عند {CONCURRENT_USERS} مستخدم متزامن")
    else:
        print(f"✅ السيرفر استحمل {CONCURRENT_USERS} مستخدم متزامن كويس. جرّب رقم أعلى (100, 200) وشوف فين بيبدأ يفشل.")

    if failed:
        print("\nأمثلة من الطلبات الفاشلة:")
        for r in [r for r in all_results if not r["success"]][:5]:
            print(f"  status={r['status']}  time={r['ms']:.0f}ms")


if __name__ == "__main__":
    main()