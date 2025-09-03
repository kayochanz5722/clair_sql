-- Исправление проблемы с материализованным представлением chat_stats
-- Удаляем проблемные триггеры и материализованное представление

-- Удаляем триггеры, которые вызывают проблемы
DROP TRIGGER IF EXISTS trigger_update_chat_stats_insert ON chat_messages;
DROP TRIGGER IF EXISTS trigger_update_chat_stats_update ON chat_messages;
DROP TRIGGER IF EXISTS trigger_update_chat_stats_delete ON chat_messages;

-- Удаляем функции триггеров
DROP FUNCTION IF EXISTS update_chat_stats_on_message_change();

-- Удаляем материализованное представление
DROP MATERIALIZED VIEW IF EXISTS chat_stats;

-- Удаляем функцию обновления материализованного представления
DROP FUNCTION IF EXISTS refresh_chat_stats();

-- Проверяем, что все проблемные объекты удалены
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes 
WHERE indexname LIKE '%chat_stats%';

SELECT 
    schemaname,
    matviewname
FROM pg_matviews 
WHERE matviewname = 'chat_stats';

SELECT 
    proname
FROM pg_proc 
WHERE proname IN ('update_chat_stats_on_message_change', 'refresh_chat_stats');

-- Выводим сообщение об успешном удалении
SELECT 'Проблемные объекты материализованного представления удалены' as status;
