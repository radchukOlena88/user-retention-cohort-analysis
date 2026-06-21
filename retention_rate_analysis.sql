--CTE для очищення дат (де ми виключаємо зайві пробіли в компонентах часу, замінюємо делімітери на єдиний та свтановлюємо єдиний формат дати) у cohort_users_raw
WITH user_parsed as (
    select user_id,
        promo_signup_flag,
        case
            when split_part(trim(signup_datetime), ' ', 1)  ~ '[0-9]{1,2}[./-][0-9]{1,2}[./-][0-9]{4}' then
                to_date(replace(replace(split_part(trim(signup_datetime), ' ', 1), '.', '/'), '-', '/'),
                    'DD/MM/YYYY')
            when split_part(trim(signup_datetime), ' ', 1) ~ '[0-9]{1,2}[./-][0-9]{1,2}[./-][0-9]{2}' then
                to_date(regexp_replace(
                       replace(replace(split_part(trim(signup_datetime), ' ', 1), '.', '/'), '-', '/'),
                        '([0-9]{1,2}/[0-9]{1,2}/)([0-9]{2})', '\1' || '20' || '\2'), 'DD/MM/YYYY')
            else null
        end as signup_date
    from cohort_users_raw),
    --CTE для очищення дат(де ми виключаємо зайві пробіли в компонентах часу, замінюємо делімітери на єдиний та свтановлюємо єдиний формат дати) у cohort_events_raw
event_parsed as (
    select user_id,
        event_type,
        event_datetime,
         case
            when split_part(trim(event_datetime), ' ', 1) ~ '[0-9]{1,2}[./-][0-9]{1,2}[./-][0-9]{4}' then
                to_date(replace(replace(split_part(trim(event_datetime), ' ', 1), '.', '/'), '-', '/'),
                    'DD/MM/YYYY'                )
            when split_part(trim(event_datetime), ' ', 1) ~ '[0-9]{1,2}[./-][0-9]{1,2}[./-][0-9]{2}' then
                to_date(regexp_replace(
                       replace(replace(split_part(trim(event_datetime), ' ', 1), '.', '/'), '-', '/'),
                        '([0-9]{1,2}/[0-9]{1,2}/)([0-9]{2})', '\1' || '20' || '\2'), 'DD/MM/YYYY')
           else null
        end as event_date
    from cohort_events_raw),
    -- СТЕ для об'єднання двох очищених таблиць та побудова когортної таблиці із застосуванням фільтрації
user_activity as (
    select u.user_id,
        u.promo_signup_flag,
        DATE_TRUNC('month', u.signup_date)::date as cohort_month,
        e.event_type,
        e.event_date,
        e.event_datetime,
       (extract(year from age(date_trunc('month', e.event_date), 
                              date_trunc('month', u.signup_date)
                              )) * 12 + extract(month from age(
                               date_trunc('month', e.event_date),
                               date_trunc('month', u.signup_date))
                               ))::int as month_offset
    from user_parsed u
    join event_parsed e
    on u.user_id = e.user_id
    where u.signup_date is not null
    and e.event_date is not null
    and e.event_type is not null
    and e.event_type <> 'test_event'
    and e.event_date between date '2025-01-01' and date '2025-06-30')
    --фінальний select із створенням агрегованої таблиці
select promo_signup_flag,
       cohort_month,
       month_offset,
       count(distinct user_id) as users_total
from user_activity
group by promo_signup_flag, 
         cohort_month, 
         month_offset
order by promo_signup_flag, 
         cohort_month, 
         month_offset;


        