/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Васильев Артём Викторович
 * Дата: 24.04.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT
       COUNT(id) AS number_players,
       SUM(payer) AS number_paying_players,
       ROUND(AVG(payer),4) AS percentage_paying_players
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
       r.race,
       SUM(u.payer) AS number_paying_players,
       COUNT(u.id) AS number_players,
       ROUND(CAST(SUM(u.payer) AS NUMERIC) / COUNT(u.id),4) AS percentage_paying_players
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY percentage_paying_players DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
       COUNT(transaction_id) AS number_transactions,
       SUM(amount) AS total_cost,
       MIN(amount) AS minimum_cost,
       (SELECT MIN(amount) FROM fantasy.events WHERE amount != 0) AS min_no_zero,
       MAX(amount) AS maximum_cost,
       AVG(amount)::NUMERIC(10, 2) AS avg_cost,
       PERCENTILE_DISC(0.50) WITHIN GROUP(ORDER BY amount) AS median,
       STDDEV(amount)::NUMERIC(10, 2) AS stand_dev
FROM fantasy.events

-- 2.2: Аномальные нулевые покупки:
SELECT 
       COUNT(*) AS zero_cost,
       CAST(COUNT(*) AS NUMERIC) / (SELECT COUNT(*) FROM fantasy.events) AS zero_cost_percentage
FROM fantasy.events 
WHERE amount = 0;
       
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
       WITH game_statistics AS (
SELECT
       u.payer,
       e.id,
       COUNT(e.transaction_id) AS number_transactions,
       SUM(e.amount) AS total_cost
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id = e.id
WHERE e.amount != 0
GROUP BY u.payer, e.id
)
SELECT
       CASE
       WHEN
            payer = 1
       THEN 
            'Paying_player'
       ELSE
            'No_paying_player'
       END,
       COUNT(payer) AS number_players_category,
       AVG (number_transactions) AS avg_number_transactions,
       AVG(total_cost) AS avg_total_cost
FROM  game_statistics
GROUP BY payer;
       

-- 2.4: Популярные эпические предметы:
 SELECT
        i.game_items,
        COUNT(e.transaction_id) AS total_transaction,
        CAST(COUNT(e.transaction_id) AS NUMERIC) / (SELECT COUNT(*) FROM fantasy.events WHERE amount != 0) AS sales_share,
        CAST(COUNT(DISTINCT e.id) AS NUMERIC) / (SELECT COUNT(DISTINCT id) FROM fantasy.events) AS user_share
FROM fantasy.events e
INNER JOIN fantasy.items i ON e.item_code = i.item_code
INNER JOIN fantasy.users u ON e.id = u.id
WHERE e.amount != 0
GROUP BY i.game_items
ORDER BY total_transaction DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH count_race_player AS (
SELECT 
       r.race,
       COUNT(DISTINCT u.id) AS count_player
FROM fantasy.users AS u 
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id 
GROUP BY r.race
),
     game_stat AS (
SELECT 
       r.race,
       u.payer,
       e.id,
       COUNT(DISTINCT u.id) AS number_pay_player,
       COUNT(e.transaction_id) AS number_transactions,
       SUM(e.amount) AS total_amount
FROM fantasy.users AS u 
JOIN fantasy.race AS r ON u.race_id = r.race_id 
JOIN fantasy.events AS e ON u.id = e.id
WHERE e.amount > 0
GROUP BY r.race,u.payer,e.id
)
SELECT
       gs.race,
       count_player,
       COUNT(id) AS paying_players,
       COUNT(id) / CAST(count_player AS NUMERIC) AS share_of_paying_players,
       SUM(payer) AS number_of_buyers,
       AVG(payer) AS avg_buyers,
       AVG(number_transactions) AS avg_number_transactions,
       AVG(total_amount) / AVG(number_transactions) AS avg_total_amount_one_player,
       AVG(total_amount) AS avg_total_amount
FROM game_stat AS gs
JOIN count_race_player AS crp ON gs.race = crp.race
GROUP BY gs.race,count_player;


-- Задача 2: Частота покупок
Обязательно сделаю для себя когда буду дома,а пока я на вахте времени и так не много :(