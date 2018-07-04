# 產出每日監控報告的工具(for Oracle)
確保 CIA 原則的每日監控，成品可參考 [noLogAlertTemplate_Sample](https://github.com/JacksonSie/noLogAlert/blob/master/noLogAlertTemplate_Sample.html) ，如下圖
![demo](https://github.com/JacksonSie/noLogAlert/blob/master/demo.gif)

## 使用方式
1. 必先 Crete procedure (noLogAlert.sql)
1. 可使用 bash 呼叫 noLogAlert.sh
1. 開啟 html 產品後，可按下左邊的設備名稱、或摺線圖上的圓點把線段消除，如下圖 
![click](https://github.com/JacksonSie/noLogAlert/blob/master/click.gif)

## 自動產出報告工具(noLogAlert.sh)
```bash
./noLogAlert.sh date_period [--not-update]
# date_period 1-99, 默認從呼叫日的昨天開始往前數 (= ./this.sh 1)
# 產出從昨天開始起算 ~ date_period 日前的事件數報告
# 若有 --not-update，則為跳過更新程序，直接產出報告
```
