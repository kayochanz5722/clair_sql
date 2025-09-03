-- Оптимизация производительности чатов - только индексы
-- Этот скрипт создает только индексы без функций PostgreSQL

-- Индекс для быстрого поиска сообщений по chat_id и created_at
-- Это критически важно для пагинации сообщений
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_created 
ON chat_messages (chat_id, created_at DESC);

-- Индекс для быстрого поиска непрочитанных сообщений
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread 
ON chat_messages (chat_id, sender_id, is_read) 
WHERE is_read = false;

-- Индекс для быстрого поиска чатов пользователя
CREATE INDEX IF NOT EXISTS idx_chats_participant1 
ON chats (participant1_id, last_message_time DESC);

CREATE INDEX IF NOT EXISTS idx_chats_participant2 
ON chats (participant2_id, last_message_time DESC);

-- Индекс для быстрого поиска чата между двумя пользователями
CREATE INDEX IF NOT EXISTS idx_chats_participants 
ON chats (participant1_id, participant2_id);

-- Индекс для быстрого подсчета сообщений в чате
CREATE INDEX IF NOT EXISTS idx_chat_messages_count 
ON chat_messages (chat_id);

-- Анализируем таблицы для обновления статистики
ANALYZE chats;
ANALYZE chat_messages;

-- Выводим информацию о созданных индексах
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('chats', 'chat_messages')
ORDER BY tablename, indexname;

-- Проверяем производительность запросов
EXPLAIN (ANALYZE, BUFFERS) 
SELECT c.id, c.participant1_id, c.participant2_id, c.participant1_name, c.participant2_name, c.participant1_username, c.participant2_username, c.last_message, c.last_message_time, c.is_read, c.created_at, c.updated_at
FROM chats c
WHERE c.participant1_id = '00000000-0000-0000-0000-000000000000'::UUID OR c.participant2_id = '00000000-0000-0000-0000-000000000000'::UUID
ORDER BY c.last_message_time DESC NULLS LAST, c.updated_at DESC;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, chat_id, sender_id, sender_name, sender_username, content, created_at, is_read, reply_to_message_id, reply_to_content
FROM chat_messages 
WHERE chat_id = '00000000-0000-0000-0000-000000000000'::UUID
ORDER BY created_at DESC
LIMIT 50 OFFSET 0;
