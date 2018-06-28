# 產出每日監控報告的工具(for Oracle)
確保 CIA 原則的每日監控


## 使用方式
1. 必先 Crete procedure (noLogAlert.sql)
1. 可使用 bash 呼叫 noLogAlert.sh

## 自動產出報告工具(noLogAlert.sh)
```bash
./noLogAlert.sh date_period [--not-update]
# date_period 1-99, 默認從呼叫日的昨天開始往前數 (= ./this.sh 1)
# 產出從昨天開始起算 ~ date_period 日前的事件數報告
# 若有 --not-update，則為跳過更新程序，直接產出報告
```
