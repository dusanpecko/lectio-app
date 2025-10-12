-- Sample notification topics for testing
-- Run this AFTER applying the RLS policies migration

INSERT INTO notification_topics (
  name_sk, 
  name_en, 
  name_cs, 
  name_es,
  slug, 
  description_sk, 
  description_en,
  icon, 
  category, 
  display_order,
  is_active,
  is_default
) VALUES
-- Spiritual category
(
  'Denné zamyslenia',
  'Daily Reflections',
  'Denní úvahy',
  'Reflexiones diarias',
  'daily-reflections',
  'Každodenné duchovné zamyslenia a úvahy',
  'Daily spiritual reflections and meditations',
  '🙏',
  'spiritual',
  1,
  true,
  true
),
(
  'Modlitby',
  'Prayers',
  'Modlitby',
  'Oraciones',
  'prayers',
  'Ranné a večerné modlitby, Ruženec',
  'Morning and evening prayers, Rosary',
  '🕊️',
  'spiritual',
  2,
  true,
  true
),

-- Educational category
(
  'Biblické výklady',
  'Biblical Interpretations',
  'Biblické výklady',
  'Interpretaciones bíblicas',
  'biblical-interpretations',
  'Výklad biblických textov a komentáre',
  'Biblical text interpretations and commentaries',
  '📖',
  'educational',
  3,
  true,
  false
),
(
  'Liturgický kalendár',
  'Liturgical Calendar',
  'Liturgický kalendář',
  'Calendario litúrgico',
  'liturgical-calendar',
  'Liturgické slávenia a sviatky',
  'Liturgical celebrations and feasts',
  '📅',
  'educational',
  4,
  true,
  false
),
(
  'Katechézy',
  'Catechesis',
  'Katecheze',
  'Catequesis',
  'catechesis',
  'Náučné texty o viere a cirkvi',
  'Educational texts about faith and church',
  '📚',
  'educational',
  5,
  true,
  false
),

-- News category
(
  'Aktuality',
  'News',
  'Aktuality',
  'Noticias',
  'news',
  'Novinky a oznamy z aplikácie',
  'App news and announcements',
  '📰',
  'news',
  6,
  true,
  false
),

-- Reminders category
(
  'Denné pripomienky',
  'Daily Reminders',
  'Denní připomínky',
  'Recordatorios diarios',
  'daily-reminders',
  'Pripomienky na modlitbu a čítanie',
  'Reminders for prayer and reading',
  '⏰',
  'reminders',
  7,
  true,
  true
),

-- Special category
(
  'Sviatky a slávnosti',
  'Feasts and Celebrations',
  'Svátky a slavnosti',
  'Fiestas y celebraciones',
  'feasts-celebrations',
  'Pripomienky na dôležité sviatky',
  'Reminders for important feasts',
  '✨',
  'special',
  8,
  true,
  false
)

ON CONFLICT (slug) DO NOTHING;

-- Verify insertion
SELECT 
  slug,
  name_sk,
  name_en,
  icon,
  category,
  display_order,
  is_active,
  is_default
FROM notification_topics
ORDER BY display_order;
