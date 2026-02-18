/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Манузин Никита
 * Дата: 30.08.2025
*/

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

-- Напишите ваш запрос здесь
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
    ),
    --Категоризируем объявления по региону и типу населенного пункта
category AS(
	SELECT
		CASE 
			WHEN city_id = '6X8I' THEN 'Санкт-Петербург'
			WHEN city_id <> '6X8I' AND type_id = 'F8EM' THEN 'ЛО'
		END AS region,
		CASE 
			WHEN days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
			WHEN days_exposition BETWEEN 31 AND 90 THEN 'до 3 месяцев'
			WHEN days_exposition BETWEEN 91 AND 181 THEN 'до полугода'
			WHEN days_exposition > 181 THEN 'более полугода'
			ELSE 'активные объявления'
		END AS segment,
		*,
		a.last_price/f.total_area AS cost_metr
	FROM real_estate.flats AS f
	INNER JOIN real_estate.advertisement AS a USING(id)
	INNER JOIN filtered_id AS fi USING(id)
	WHERE type_id = 'F8EM'
)
SELECT 
	region,
	segment,
	COUNT(*) AS count_adv,
	ROUND(AVG(last_price)::NUMERIC,2) AS avg_cost,
	ROUND(AVG(cost_metr)::NUMERIC,2) AS avg_cost_metr,
	ROUND(AVG(total_area)::NUMERIC,2) AS avg_area,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY floor) AS median_floor,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY floors_total) AS median_total_floors,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY ceiling_height) AS median_ceiling_heights
FROM category
WHERE EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
GROUP BY region, segment
ORDER BY region DESC, count_adv DESC;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Напишите ваш запрос здесь
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
    ),
--Объединяем информацию об объявлениях и квартирах, находим дату снятия объявления и цену квадратного метра
flats_info AS (
    SELECT 
        a.id,
        a.first_day_exposition,
        a.days_exposition,
        a.last_price,
        f.total_area,
        a.first_day_exposition + (a.days_exposition *'1 day'::INTERVAL) AS close_date,
        a.last_price /f.total_area AS price_metr
    FROM real_estate.advertisement AS a
    INNER JOIN real_estate.flats AS f USING(id)
    INNER JOIN filtered_id AS fi USING(id)
    WHERE (EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018) AND type_id = 'F8EM'
),
-- Считаем показатели по опубликованным объявлениям
sell_stats AS (
    SELECT 
        EXTRACT(MONTH FROM first_day_exposition) AS month_sell,
        COUNT(*) AS sell_total,
        AVG(price_metr) AS avg_cost_metr_sell,
        AVG(total_area) AS avg_area_sell
    FROM flats_info
    GROUP BY EXTRACT(MONTH FROM first_day_exposition)
),
--Считаем показатели по снятым объявлениям)
buy_stats AS (
    SELECT 
        EXTRACT(MONTH FROM close_date) AS month_buy,
        COUNT(*) AS buy_total,
        AVG(price_metr) AS avg_cost_metr_buy,
        AVG(total_area) AS avg_area_buy
    FROM flats_info
    WHERE days_exposition IS NOT NULL
    GROUP BY EXTRACT(MONTH FROM close_date)
)
SELECT 
 month_sell AS monthly,
 sell_total,
 RANK() OVER(ORDER BY sell_total DESC) AS sell_rank,
 avg_cost_metr_sell::NUMERIC(8,2),
 avg_area_sell::NUMERIC(4,2),
 buy_total,
 RANK() OVER(ORDER BY buy_total DESC) AS buy_rank,
 avg_cost_metr_buy::numeric(8,2),
 avg_area_buy::numeric(4,2)
FROM sell_stats AS ss
FULL JOIN buy_stats AS bs ON ss.month_sell = bs.month_buy
ORDER BY monthly;

