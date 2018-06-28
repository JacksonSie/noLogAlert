#!/bin/bash
#last modified : see ls -l ./this.sh
#output : html with emailed
#desc : 為每日個別客戶+設備的 log 量進行統計
#

date_period=$1

if [[ $# < 1 ]] || [[ ! $date_period =~ '^([1-9][0-9]?){1}$' ]];then
        echo 'usage : ./this.sh date_period' >&2
        echo 'date_period is int in 1-99' >&2
        exit 1
fi

mail_list='
        reporter@wt.moc.radio
        ,op@wt.moc.radio
        ,dev@wt.moc.radio
'

export LANG='en_US.UTF-8'
export NLS_LANG=American_America.UTF8
export ORACLE_HOME=/opt/oracle/product/
export ORACLE_SID=something_SID
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$ORACLE_HOME/bin:$PATH
range=`/bin/date -d "-$1 days" +%Y%m%d`' - '`/bin/date -d "-1 days" +%Y%m%d`
[[ $2 == '--not-update' ]] && not_update=" p_only_update_view => 'Y' "
PASSFILE=/radio/def/.PASSfile;USERNAME=USER;SCHEMA=$ORACLE_SID;usrpass=`cat $PASSFILE|grep $SCHEMA|grep $USERNAME|awk '{print $3}'`;#echo $USERNAME/$usrpass@$SCHEMA
queryfile=/tmp/noLogAlert-$RANDOM$RANDOM.sql
template_svg_html=/radio/SCT/noLogAlertTemplate.html
svg_html=/tmp/noLogAlertSVG.html

for (( i=$date_period;i>0;i-- ));do
    tmp=$(date +%Y%m%d --date="${i} days ago")
    tmp_week=$(date +%a --date="${i} days ago")
    result="$result,\"$tmp\" as \"$tmp($tmp_week)\""
done

echo -e "SET FEEDBACK OFF ECHO OFF PAGESIZE 50000 newpage 0 space 0 linesize 1000 long 9999999 trimspool ON trimout OFF MARKUP HTML ON ;
exec SOCMGR.noLogAlertDailyMaintainer($not_update);
SELECT COMP_NAME as COMPANY
    ,FACILITY_NAME as FACILITY
    $result
FROM CUST_FACILITY_COUNT_BY_DAY_V
order by COMP_NAME , FACILITY_NAME;
exit" >> $queryfile
echo $queryfile
cat $queryfile
spool_html=$(sqlplus -s $USERNAME/$usrpass@$SCHEMA @$queryfile)

#解決不同browser問題
easy_css_and_htmlMeta='<style type="text/css"> table { background: #f0f0f0; font-size: 90%; } th { background: #aaa; } td { padding: 5px; } </style> <meta http-equiv="Content-Type" content="text/html; charset=utf-8">'

spool_svg=$(echo $spool_html|sed 's/\//\\\//g')
cp $template_svg_html $svg_html

#sed -i 'foo' foo有字數的限制，用 eof 可以 bypass
sed -i -f - $svg_html << EOF
s/v_table_replace_here/$spool_svg/g
EOF

echo $spool_html|
sed 's/ <td align="right"> 0 <\/td>/<td align="right" style="color:#FF0000"> 0 <\/td>/g'| #0要上色
sed "1i$easy_css_and_htmlMeta"|
mutt -e 'set content_type=text/html' -s "$range no log alert" -a $svg_html $mail_list

exit

