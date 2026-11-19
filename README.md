# Assurity Performance Testing Assignment

This repository contains an Apache JMeter performance testing framework for the Trade Me Sandbox Category Details API (`GET /v1/Categories/{categoryId}/Details.json?catalogue=false`), built to satisfy the functional and non-functional requirements of the Assurity performance testing assignment.

---

## 1. Repository Structure

```text
assurity-perftest-assignment/
├── assurity_api_testplan.jmx          # Main orchestration test plan (workload, CSV config, throughput pacing)
├── fragments/
│   └── assurity_api_category.jmx      # Modular Test Fragment (HTTP sampler, Groovy assertion, Debug thread group)
├── data/
│   └── tmsandbox_category.csv         # Test data (Category IDs 6327–6336)
├── log/
│   ├── results.jtl                    # Raw JMeter test results from non-GUI execution
│   └── performance_test_results_20261119_195638.csv  # Extracted Promotion ID & Price CSV output
├── report/                            # Generated JMeter HTML Dashboard Report (open report/index.html)
└── README.md                          # Execution guide, assumptions, and Performance Test Report
```

### Framework Design Highlights
* **Modular Test Plan + Fragment:** `assurity_api_testplan.jmx` manages environment variables, workload parameters, CSV test data, and throughput pacing, while `fragments/assurity_api_category.jmx` encapsulates the API request, Groovy validation, and CSV extraction—plus an isolated `Debug` Thread Group for single-user GUI troubleshooting.
* **Centralised Data Server Placeholder:** The fragment includes a disabled `DATASOURCE (Placeholder)` controller demonstrating how local CSV files can be replaced with a centralised test data service (`${host_central_data}:3000/api/search`) in distributed load runs, while defaulting to `data/tmsandbox_category.csv` for zero-dependency local execution.
* **Groovy `JSR223Assertion` (with `cacheKey="true"`):**
  1. Verifies HTTP status code `200`.
  2. Parses JSON safely and validates `CategoryId` matches `${param_category_id}`.
  3. Validates `"CanRelist": true` (explicitly distinguishing a missing field from `false`).
  4. On assertion pass (and when not running in `Debug`), thread-safely appends `Category ID`, `Name`, `Path`, `Promotion ID`, and `Price` for **every promotion** of the category to `log/performance_test_results_<TESTSTART>.csv` using `synchronized(csvFilePath.intern())`.
* **Zero External Plugin Dependencies:** Uses JMeter's built-in `ConstantThroughputTimer` so the plan loads and runs out-of-the-box on any standard Apache JMeter 5.6.3 installation.

---

## 2. Prerequisites & Setup

* **Apache JMeter:** `5.6.3`
* **Java (JDK):** **Java 8, 11, 17, or 21** (LTS).
  * *Note:* JMeter 5.6.3 bundles Groovy 3.0.20, which does not support Java 25+ bytecode (`Unsupported class file major version 69`). If multiple JDKs are installed, ensure `JAVA_HOME` points to JDK 21 or earlier before running JMeter.
* **Network Access:** Outbound HTTPS access to `api.tmsandbox.co.nz`.

---

## 3. Non-GUI Execution Instructions

Run the test from the repository root in non-GUI mode:

```powershell
# Optional (if default system Java is > 21):
# $env:JAVA_HOME = "C:\Program Files\Java\jdk-21.0.13"
# $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# Clean previous report folder if re-running
Remove-Item -Recurse -Force report -ErrorAction SilentlyContinue

# Execute with default assignment parameters and generate HTML dashboard report
jmeter -n -t assurity_api_testplan.jmx -l log/results.jtl -e -o report
```

### Configurable Execution Parameters (`-J` CLI Overrides)

All workload and target parameters are exposed via `${__P(...)}` so they can be overridden from the command line without editing the `.jmx` file:

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `users_api_category` | `5` | Number of VUsers (Threads) — half of the 10 Category IDs in `data/tmsandbox_category.csv` (NFR-01) |
| `rampup_api_category` | `5` | Ramp-up period in seconds — 1 VUser per second for 5 threads (NFR-02) |
| `duration_api_category` | `65` | Total test duration in seconds (`5s` ramp-up + `60s` steady state) (NFR-03) |
| `tph_api_category` | `600` | Target throughput in hits per hour (`600` TPH = `10` requests/minute) (NFR-03) |
| `host_tmsandbox` | `api.tmsandbox.co.nz` | Target API host |
| `scheme_tmsandbox` | `https` | Target protocol scheme |

**Example custom run (e.g., 10 VUsers, 10s ramp-up, 120s duration, 1200 TPH):**
```powershell
jmeter -n -t assurity_api_testplan.jmx `
  -Jusers_api_category=10 `
  -Jrampup_api_category=10 `
  -Jduration_api_category=120 `
  -Jtph_api_category=1200 `
  -l log/results_custom.jtl -e -o report_custom
```

---

## 4. Assumptions

1. **Ramp-Up vs. Steady State Duration:** In JMeter's standard `ThreadGroup`, `ThreadGroup.duration` includes `ramp_time`. To provide a full 1-minute (`60s`) steady-state window after the `5s` ramp-up (NFR-02 + NFR-03), `duration_api_category` defaults to `65` seconds.
2. **Throughput Pacing:** `ConstantThroughputTimer` is configured with `calcMode=4` (*All active threads in current thread group (shared)*) driven by `${tph_api_category} / 60.0` (`10.0` samples/min). Because `tph_api_category=600` corresponds to 1 request every 6 seconds across 5 threads, `11` total HTTP requests occur over the `65s` window (~`10` calls in steady state).
3. **CSV Extraction Scope:** Promotion rows are written to `log/performance_test_results_*.csv` only when all functional assertions pass (`HTTP 200`, `CategoryId` match, and `CanRelist == true`). Failed samples are recorded in `log/results.jtl` with their assertion failure message and are intentionally excluded from the passing CSV output.
4. **Disabled `View Results Tree`:** `View Results Tree` is disabled in `assurity_api_testplan.jmx` following JMeter non-GUI best practices to avoid unnecessary memory overhead.

---

## 5. Performance Test Report

### Purpose
Validate that `GET https://api.tmsandbox.co.nz/v1/Categories/{id}/Details.json?catalogue=false` (across Category IDs `6327–6336`) meets functional correctness criteria and satisfies the non-functional SLAs under a paced 5-VUser load profile.

### NFR Verification Summary

| NFR | Requirement | Configured / Observed | Status |
| :--- | :--- | :--- | :--- |
| **NFR-01** | VUsers = half the count of Category IDs (`10 / 2 = 5`) | `5` Threads (`users_api_category=5`) | **Pass** |
| **NFR-02** | Ramp-up at 1 VUser/sec | `5s` ramp-up for `5` Threads (`rampup_api_category=5`) | **Pass** |
| **NFR-03** | 10 API calls in 1-minute steady state | `11` total HTTP calls over `65s` (`~10` in `60s` steady state; `0.184 req/s`) | **Pass** |
| **NFR-04** | 90% of API responses within `500 ms` | Observed 90th percentile = `713.8 ms` (Median: `95.0 ms`, Mean: `209.4 ms`) | **Fail (Cold-Start Skew)** |

### Local Run Summary (`Category - HTTP Request`)
*Source: [log/results.jtl](log/results.jtl) and [report/statistics.json](report/statistics.json)*

| Metric | Value |
| :--- | :--- |
| **Total HTTP Samples** | `11` |
| **Passed / Failed** | `10` Passed / `1` Failed (`9.09%` error rate) |
| **Min Response Time** | `60 ms` |
| **Median (50th pct)** | `95.0 ms` |
| **Mean Response Time** | `209.36 ms` |
| **90th Percentile** | `713.8 ms` |
| **Max Response Time** | `718 ms` |
| **Throughput** | `0.184 req/s` (`~11.0 req/min`) |
| **Extracted CSV Output** | [log/performance_test_results_20261119_195638.csv](log/performance_test_results_20261119_195638.csv) (`41` lines: `1` header + `40` promotion rows) |

### Observations & Commentary

1. **Why 90th Percentile Exceeded 500 ms (`713.8 ms` vs `500 ms` SLA):**
   * Inspection of [log/results.jtl](log/results.jtl) shows that **9 out of 11** requests completed between **`60 ms` and `250 ms`** (median `95 ms`), well within the `500 ms` target.
   * The only two requests over `500 ms` were the very first two samples (`718 ms` with `641 ms` connect time, and `697 ms` with `619 ms` connect time), caused by initial TCP/TLS handshake cold-start overhead. Subsequent keep-alive requests had `0–30 ms` connect times.
   * Because NFR-03 limits the 1-minute test to ~10 samples, 2 cold-start samples represent `18%` of the dataset and directly push the 90th percentile above `500 ms`. In a longer steady-state run (or with connection warm-up), the 90th percentile would sit comfortably under `250 ms`.

2. **Functional Assertion Failure on Category `6331`:**
   * `1` of the `11` requests failed the Groovy assertion:
     `Assertion Failed: 'CanRelist' value is not true for 6331`
   * The live sandbox endpoint `https://api.tmsandbox.co.nz/v1/Categories/6331/Details.json?catalogue=false` returns HTTP `200` with `"CanRelist": false`. The assertion correctly detected and flagged this data mismatch rather than silently passing on HTTP `200`.

3. **Transaction Controller Shutdown Samples:**
   * In `log/results.jtl`, `Assurity_API_Category` shows `16` total rows (`11` completed transactions + `5` zero-millisecond wrapper events when the 5 threads were interrupted from `ConstantThroughputTimer` sleep at the end of the `65s` scheduler window). All HTTP-level metrics above are reported directly from `Category - HTTP Request` (`11` samples) for accuracy.
