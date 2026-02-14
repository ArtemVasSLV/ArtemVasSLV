--Проект первого модуля: анализ данных агентств недвижимости
--Автор: Васильев Артём
--Дата: 17 мая 2025 г.


-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ) 
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
        OR ceiling_height IS NULL)
),
region_counts AS (
    SELECT 
        CASE 
	        WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END AS region,
        COUNT(*) AS total_ads
    FROM real_estate.flats AS f
    INNER JOIN real_estate.city AS c ON c.city_id = f.city_id
    INNER JOIN real_estate.advertisement AS a ON a.id = f.id
    WHERE f.id IN (SELECT id FROM filtered_id) 
         AND days_exposition IS NOT NULL 
         AND type_id = 'F8EM'
    GROUP BY region
)
SELECT 
    CASE 
	    WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END AS region,
    CASE 
        WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1 месяц'
        WHEN a.days_exposition BETWEEN 31 AND 90 THEN '1 квартал'
        WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'Пол года'
        WHEN a.days_exposition >= 181 THEN '> 6 месяцев' 
        END AS seg_activ,
    COUNT(*) AS ads_count,
    ROUND(COUNT(*) * 100.0 / rc.total_ads, 1) AS percentage,
    AVG(last_price / total_area) AS avg_cost,
    AVG(total_area) AS avg_square,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_comnate,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balances,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_stages
FROM real_estate.flats AS f
INNER JOIN real_estate.city AS c ON c.city_id = f.city_id 
INNER JOIN real_estate.advertisement AS a ON a.id = f.id
INNER JOIN region_counts AS rc ON rc.region = CASE WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END
WHERE 
    f.id IN (SELECT id FROM filtered_id) 
    AND days_exposition IS NOT NULL 
    AND type_id = 'F8EM'
GROUP BY 
    CASE WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END,
    CASE 
        WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1 месяц'
        WHEN a.days_exposition BETWEEN 31 AND 90 THEN '1 квартал'
        WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'Пол года'
        WHEN a.days_exposition >= 181 THEN '> 6 месяцев' 
    END,
    rc.total_ads
ORDER BY region DESC, seg_activ ASC;
-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

--Анализ по публикациям
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
        OR ceiling_height IS NULL)
)
SELECT 
       COUNT(f.id) AS number_ads,
       EXTRACT(month FROM first_day_exposition) AS month_publication,
       AVG (last_price / total_area) AS avg_cost,
       AVG(total_area) AS avg_space
FROM real_estate.flats AS f 
INNER JOIN real_estate.advertisement AS a ON a.id = f.id
WHERE f.id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM'
GROUP BY month_publication
ORDER BY number_ads DESC;
   --Анализ по снятиям
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
        OR ceiling_height IS NULL)
)
SELECT 
       COUNT(f.id) AS number_ads,
       EXTRACT(month FROM first_day_exposition::date  + days_exposition::INT) AS withdrawal_month,
       AVG (last_price / total_area) AS avg_cost,
       AVG(total_area) AS avg_space
FROM real_estate.flats AS f 
INNER JOIN real_estate.advertisement AS a on a.id = f.id
WHERE f.id IN (SELECT * FROM filtered_id) and days_exposition IS NOT NULL AND type_id = 'F8EM'
GROUP BY withdrawal_month
ORDER BY number_ads DESC;


-- Задача 3: Анализ рынка недвижимости Ленобласти
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
        OR ceiling_height IS NULL)
)
SELECT 
    c.city,
    COUNT(f.id) AS  number_ads,
    SUM(CASE WHEN days_exposition IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(f.id) AS percentage_removed_ads,
    AVG(days_exposition) AS avg_activity_time,
    AVG(last_price/total_area) AS avg_price_m2,
    AVG(total_area) AS avg_space,
    AVG(rooms) AS avg_number_rooms
FROM real_estate.flats AS f
INNER JOIN real_estate.city AS c ON c.city_id = f.city_id 
INNER JOIN real_estate.advertisement AS a ON a.id = f.id
WHERE 
    f.id IN (SELECT id FROM filtered_id) 
    AND c.city != 'Санкт-Петербург'
GROUP BY c.city
ORDER BY number_ads DESC
LIMIT 10;