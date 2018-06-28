CREATE OR REPLACE PROCEDURE SOCMGR.noLogAlertDailyMaintainer (
    p_cust_id in number default null
    , p_date_start in date default null 
    , p_date_end in date default null 
    , p_only_update_view in char default 'N' ) IS
--p_cust_id no log alert 要維護的客戶編號，若留空則依 CUST_STATUS_CONFIG 而定
--p_date_start no log alert 要維護的時間開始，若留空則為昨天一天的開始
--p_date_end  no log alert 要維護的時間結束，若留空則為昨天一天的結束
--p_only_update_view 是否只更新呈現 view CUST_FACILITY_COUNT_BY_DAY_V ，若留空則執行整個流程
begin
declare
    l_date_start date := nvl(p_date_start , trunc(sysdate , 'dd') -2);
    l_date_end date := nvl(p_date_end , trunc(sysdate , 'dd') -1/86400);
    l_query varchar2(32767);
    l_query_config_curString varchar2(4000);
    l_max_range number := 90;
    l_curr_date_end date ;
    -----
    type l_t_cursor_noLogAlert_config is ref cursor;
    l_cursor_noLogAlert_config l_t_cursor_noLogAlert_config;
    l_row_noLogAlert_config SOCMGR.CUST_STATUS_CONFIG%rowtype;
    type l_t_available_col is table of varchar2(100) index by binary_integer;
    l_available_col l_t_available_col;
    
begin
    execute immediate 'alter session set nls_date_format = ''yyyy-mm-dd hh24:mi:ss''';    --避免 l_curr_date_end 型別錯誤
    if (l_date_start >l_date_end) and (l_date_start is not null or l_date_end is not null ) then 
        dbms_output.put_line('date_start must earilier than date_end ');
        RETURN;
    end if ;
    l_query := 'SELECT *
    FROM SOCMGR.CUST_STATUS_CONFIG 
    WHERE CUST_STATUS_CONFIG.IS_ACTIVE = 1 ';
    
    if p_only_update_view = 'Y' then 
        goto sector_only_update_view;
    end if ;
    
    if p_cust_id is not null then
        l_query := l_query || ' AND CUST_STATUS_CONFIG.CUST_ID = ' ||p_cust_id; 
    end if;
    
    ----先處理 available column 需要再細分的設備
    l_query_config_curString := l_query || ' AND available_cols is not null ';
    open l_cursor_noLogAlert_config for l_query_config_curString;
    
    /*
    :1 l_date_start
    :2 l_date_end
    :3 cust_id
    :4 rv31
    https://stackoverflow.com/questions/21899011/using-execute-immediate-with-multiple-same-bind-arguments
    */
    loop
        fetch l_cursor_noLogAlert_config into l_row_noLogAlert_config;
        exit when l_cursor_noLogAlert_config%NOTFOUND;
        l_row_noLogAlert_config.available_cols := replace(l_row_noLogAlert_config.available_cols , ',' ,' ||''/''|| ');
        dbms_output.put_line('1. available_col/evt_agent :'|| l_row_noLogAlert_config.cust_id ||',' || l_row_noLogAlert_config.available_cols); 
        if instr(upper(l_row_noLogAlert_config.available_cols) , 'EVT_AGENT') > 0 then 
            execute immediate 'begin MERGE INTO CUST_FACILITY_DAYCOUNT
                USING (
                    SELECT EVENTS.CUST_ID
                        ,TO_CHAR(EVENTS.EVT_TIME + 8 / 24, ''YYYYMMDD'') AS DATA_DAY
                        ,COUNT(*) AS COUNTS
                        ,EVENTS.RV31 || ''/'' || '|| l_row_noLogAlert_config.available_cols ||' AS FACILITY_NAME
                    FROM ESECDBA.EVENTS
                        ,ESECDBA.EVT_AGENT
                    WHERE EVENTS.AGENT_ID = EVT_AGENT.AGENT_ID
                        AND EVENTS.EVT_TIME BETWEEN :l_date_start - 8 / 24
                            AND :l_date_end - 8 / 24
                        AND EVENTS.CUST_ID = :cust_id
                        AND EVENTS.RV31 = :rv31
                    GROUP BY EVENTS.CUST_ID
                        ,TO_CHAR(EVENTS.EVT_TIME + 8 / 24, ''YYYYMMDD'')
                        ,EVENTS.RV31 || ''/'' || '|| l_row_noLogAlert_config.available_cols ||' 
                    ) events_count_list
                    ON (
                            events_count_list.CUST_ID = CUST_FACILITY_DAYCOUNT.CUST_ID
                            AND events_count_list.DATA_DAY = CUST_FACILITY_DAYCOUNT.DATA_DAY
                            AND events_count_list.FACILITY_NAME = CUST_FACILITY_DAYCOUNT.FACILITY_NAME
                            AND events_count_list.DATA_DAY BETWEEN to_char(:l_date_start, ''YYYYMMDD'')
                                AND to_char(:l_date_end, ''YYYYMMDD'')
                            )
                WHEN MATCHED THEN UPDATE 
                        SET CUST_FACILITY_DAYCOUNT.COUNTS = events_count_list.COUNTS
                WHEN NOT MATCHED THEN INSERT (CUST_ID, DATA_DAY, COUNTS, FACILITY_NAME) VALUES (
                            events_count_list.CUST_ID
                            ,events_count_list.DATA_DAY
                            ,events_count_list.COUNTS
                            ,events_count_list.FACILITY_NAME
                            );commit;end;'
            using 
                l_date_start
                ,l_date_end
                ,l_row_noLogAlert_config.cust_id
                ,l_row_noLogAlert_config.rv31;
        elsif instr(upper(l_row_noLogAlert_config.available_cols) , 'EVENTS') > 0 then
            dbms_output.put_line('1. available_col/events :'|| l_row_noLogAlert_config.cust_id ||',' || l_row_noLogAlert_config.available_cols); 
            execute immediate 'begin MERGE INTO CUST_FACILITY_DAYCOUNT
                USING (
                    SELECT EVENTS.CUST_ID
                        ,TO_CHAR(EVENTS.EVT_TIME + 8 / 24, ''YYYYMMDD'') AS DATA_DAY
                        ,COUNT(*) AS COUNTS
                        ,EVENTS.RV31 || ''/'' || '|| l_row_noLogAlert_config.available_cols ||' AS FACILITY_NAME
                    FROM ESECDBA.EVENTS
                    WHERE EVENTS.EVT_TIME BETWEEN :l_date_start  - 8 / 24
                            AND :l_date_end - 8 / 24
                        AND EVENTS.CUST_ID = :cust_id
                        AND EVENTS.RV31 = :rv31
                    GROUP BY EVENTS.CUST_ID
                        ,TO_CHAR(EVENTS.EVT_TIME + 8 / 24, ''YYYYMMDD'')
                        ,EVENTS.RV31 || ''/'' || '|| l_row_noLogAlert_config.available_cols ||'
                    ) events_count_list
                    ON (
                            events_count_list.CUST_ID = CUST_FACILITY_DAYCOUNT.CUST_ID
                            AND events_count_list.DATA_DAY = CUST_FACILITY_DAYCOUNT.DATA_DAY
                            AND events_count_list.FACILITY_NAME = CUST_FACILITY_DAYCOUNT.FACILITY_NAME
                            AND events_count_list.DATA_DAY BETWEEN to_char(:l_date_start, ''YYYYMMDD'')
                                AND to_char(:l_date_end, ''YYYYMMDD'')
                            )
                WHEN MATCHED THEN UPDATE
                        SET CUST_FACILITY_DAYCOUNT.COUNTS = events_count_list.COUNTS
                WHEN NOT MATCHED THEN INSERT ( CUST_ID ,DATA_DAY ,COUNTS ,FACILITY_NAME ) VALUES (
                            events_count_list.CUST_ID
                            ,events_count_list.DATA_DAY
                            ,events_count_list.COUNTS
                            ,events_count_list.FACILITY_NAME
                            );commit;end; '
            using 
                l_date_start
                ,l_date_end
                ,l_row_noLogAlert_config.cust_id
                ,l_row_noLogAlert_config.rv31;
        end if ;        
    end loop;
    close l_cursor_noLogAlert_config;

    ----再處理只要 rv31 即可區分的設備
    l_query := ' AND CUST_STATUS_CONFIG.CUST_ID IS NOT NULL ';
    if p_cust_id is not null then
        l_query := ' AND CUST_STATUS_CONFIG.CUST_ID = ' ||p_cust_id; 
    end if;
    dbms_output.put_line('2. rv31 :'||l_query); 
    execute immediate 'begin MERGE INTO CUST_FACILITY_DAYCOUNT
        USING (
            SELECT EVENTS.CUST_ID
                ,to_char(EVENTS.EVT_TIME + 8 / 24, ''yyyymmdd'') AS DATA_DAY
                ,COUNT(*) AS COUNTS
                ,EVENTS.RV31 AS FACILITY_NAME
            FROM esecdba.events
                ,socmgr.CUST_STATUS_CONFIG
            WHERE EVENTS.RV31 = CUST_STATUS_CONFIG.RV31
                AND EVENTS.CUST_ID = CUST_STATUS_CONFIG.CUST_ID
                '|| l_query ||' 
                AND CUST_STATUS_CONFIG.IS_ACTIVE = 1
                AND CUST_STATUS_CONFIG.AVAILABLE_COLS IS NULL
                AND EVENTS.EVT_TIME BETWEEN :l_date_start -8/24
                    AND :l_date_end -8/24
            GROUP BY EVENTS.CUST_ID
                ,to_char(EVENTS.EVT_TIME + 8 / 24, ''yyyymmdd'')
                ,EVENTS.RV31
            ) EVENT_COUNTS_LIST
            ON (
                    EVENT_COUNTS_LIST.CUST_ID = CUST_FACILITY_DAYCOUNT.CUST_ID
                    AND EVENT_COUNTS_LIST.DATA_DAY = CUST_FACILITY_DAYCOUNT.DATA_DAY
                    AND EVENT_COUNTS_LIST.FACILITY_NAME = CUST_FACILITY_DAYCOUNT.FACILITY_NAME
                    )
        WHEN MATCHED THEN UPDATE
                SET CUST_FACILITY_DAYCOUNT.COUNTS = EVENT_COUNTS_LIST.COUNTS
        WHEN NOT MATCHED THEN INSERT (CUST_ID ,DATA_DAY ,COUNTS ,FACILITY_NAME )
                VALUES (
                    EVENT_COUNTS_LIST.CUST_ID
                    ,EVENT_COUNTS_LIST.DATA_DAY
                    ,EVENT_COUNTS_LIST.COUNTS
                    ,EVENT_COUNTS_LIST.FACILITY_NAME
                    );commit;end;'
    using
        l_date_start
        ,l_date_end;
        
    ----最後處理資料呈現面(這邊就不管是否是有下客戶與日期，replace view by min(day) and max(day) of table and max_range(count down from date_end) 即可)
    <<sector_only_update_view>>
    SELECT to_date(max(CUST_FACILITY_DAYCOUNT.DATA_DAY), 'yyyymmdd')
    INTO l_curr_date_end 
    FROM CUST_FACILITY_DAYCOUNT;
    
    l_query := '';
    for date_index in 0..l_max_range loop
        l_query := l_query || ', sum(case when day_iter = '''|| to_char(l_curr_date_end - date_index , 'yyyymmdd') ||''' then counts else 0 end ) as "'|| to_char(l_curr_date_end - date_index , 'yyyymmdd') || '" '||chr(10) ; 
     end loop;
     dbms_output.put_line('3. create view :'||l_curr_date_end ); 
     execute immediate 'CREATE OR REPLACE VIEW SOCMGR.CUST_FACILITY_COUNT_BY_DAY_V AS
        SELECT FACILITY_ITER.COMP_NAME
            ,FACILITY_ITER.FACILITY_NAME
            '|| l_query ||'
        FROM (
            SELECT distinct CUST_FACILITY_DAYCOUNT.CUST_ID || ''_'' || CUST_STATUS_CONFIG.COMP_NAME AS COMP_NAME
                ,CUST_FACILITY_DAYCOUNT.CUST_ID
                ,CUST_FACILITY_DAYCOUNT.FACILITY_NAME
                ,DAY_ITER
            FROM CUST_FACILITY_DAYCOUNT
                ,CUST_STATUS_CONFIG
            CROSS JOIN (
                SELECT TO_CHAR(timestamp '''||l_curr_date_end||''' + 1 - LEVEL, ''yyyymmdd'') AS DAY_ITER
                FROM DUAL CONNECT BY LEVEL <= '||l_max_range||'
                )
            WHERE DATA_DAY BETWEEN TO_CHAR(timestamp '''||l_curr_date_end||''' - '||l_max_range||', ''yyyymmdd'')
                    AND TO_CHAR(timestamp '''||l_curr_date_end||''', ''yyyymmdd'')
                AND CUST_FACILITY_DAYCOUNT.CUST_ID = CUST_STATUS_CONFIG.CUST_ID
            ) facility_iter
        LEFT JOIN (
            SELECT CUST_FACILITY_DAYCOUNT.CUST_ID
                ,CUST_FACILITY_DAYCOUNT.FACILITY_NAME
                ,CUST_FACILITY_DAYCOUNT.DATA_DAY
                ,CUST_FACILITY_DAYCOUNT.COUNTS
            FROM CUST_FACILITY_DAYCOUNT
            WHERE DATA_DAY BETWEEN TO_CHAR(timestamp '''||l_curr_date_end||''' - '||l_max_range||', ''yyyymmdd'')
                    AND TO_CHAR(timestamp '''||l_curr_date_end||''', ''yyyymmdd'')
            ) data_source ON (
                FACILITY_ITER.CUST_ID = DATA_SOURCE.CUST_ID
                AND FACILITY_ITER.FACILITY_NAME = DATA_SOURCE.FACILITY_NAME
                AND FACILITY_ITER.DAY_ITER = DATA_SOURCE.DATA_DAY
                )
        GROUP BY FACILITY_ITER.COMP_NAME
        ,FACILITY_ITER.FACILITY_NAME';
end;
end;
/

