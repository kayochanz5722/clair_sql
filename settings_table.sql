-- Оптимизация производительности чатов
-- Создание индексов для ускорения запросов

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

-- Оптимизированный запрос для получения сообщений чата
-- Использует индекс idx_chat_messages_chat_created для быстрого доступа
CREATE OR REPLACE FUNCTION get_chat_messages_optimized(
    p_chat_id UUID,
    p_page INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    chat_id UUID,
    sender_id UUID,
    sender_name VARCHAR,
    sender_username VARCHAR,
    content TEXT,
    created_at TIMESTAMP,
    is_read BOOLEAN,
    reply_to_message_id UUID,
    reply_to_content TEXT,
    total_count BIGINT
) AS $$
DECLARE
    v_offset INTEGER;
BEGIN
    v_offset := p_page * p_limit;
    
    RETURN QUERY
    WITH message_count AS (
        SELECT COUNT(*) as total
        FROM chat_messages 
        WHERE chat_id = p_chat_id
    )
    SELECT 
        cm.id,
        cm.chat_id,
        cm.sender_id,
        cm.sender_name,
        cm.sender_username,
        cm.content,
        cm.created_at,
        cm.is_read,
        cm.reply_to_message_id,
        cm.reply_to_content,
        mc.total as total_count
    FROM chat_messages cm
    CROSS JOIN message_count mc
    WHERE cm.chat_id = p_chat_id
    ORDER BY cm.created_at ASC
    LIMIT p_limit OFFSET v_offset;
END;
$$ LANGUAGE plpgsql;

-- Оптимизированный запрос для получения чатов пользователя
CREATE OR REPLACE FUNCTION get_user_chats_optimized(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    participant1_id UUID,
    participant2_id UUID,
    participant1_name VARCHAR,
    participant2_name VARCHAR,
    participant1_username VARCHAR,
    participant2_username VARCHAR,
    last_message VARCHAR,
    last_message_time TIMESTAMP,
    is_read BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.participant1_id,
        c.participant2_id,
        c.participant1_name,
        c.participant2_name,
        c.participant1_username,
        c.participant2_username,
        c.last_message,
        c.last_message_time,
        c.is_read,
        c.created_at,
        c.updated_at
    FROM chats c
    WHERE c.participant1_id = p_user_id OR c.participant2_id = p_user_id
    ORDER BY c.last_message_time DESC NULLS LAST, c.updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Оптимизированный запрос для подсчета непрочитанных сообщений
CREATE OR REPLACE FUNCTION get_unread_message_count_optimized(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM chat_messages cm
    INNER JOIN chats c ON cm.chat_id = c.id
    WHERE (c.participant1_id = p_user_id OR c.participant2_id = p_user_id)
      AND cm.sender_id != p_user_id
      AND cm.is_read = false;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Создание материализованного представления для быстрого доступа к статистике чатов
CREATE MATERIALIZED VIEW IF NOT EXISTS chat_stats AS
SELECT 
    c.id as chat_id,
    c.participant1_id,
    c.participant2_id,
    COUNT(cm.id) as message_count,
    MAX(cm.created_at) as last_message_time,
    COUNT(CASE WHEN cm.is_read = false AND cm.sender_id != c.participant1_id THEN 1 END) as unread_count_participant1,
    COUNT(CASE WHEN cm.is_read = false AND cm.sender_id != c.participant2_id THEN 1 END) as unread_count_participant2
FROM chats c
LEFT JOIN chat_messages cm ON c.id = cm.chat_id
GROUP BY c.id, c.participant1_id, c.participant2_id;

-- Индекс для материализованного представления
CREATE INDEX IF NOT EXISTS idx_chat_stats_chat_id ON chat_stats (chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_stats_participant1 ON chat_stats (participant1_id);
CREATE INDEX IF NOT EXISTS idx_chat_stats_participant2 ON chat_stats (participant2_id);

-- Функция для обновления материализованного представления
CREATE OR REPLACE FUNCTION refresh_chat_stats()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY chat_stats;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического обновления статистики при изменении сообщений
CREATE OR REPLACE FUNCTION update_chat_stats_on_message_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Обновляем статистику для затронутого чата
    REFRESH MATERIALIZED VIEW CONCURRENTLY chat_stats;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Создаем триггеры для автоматического обновления статистики
DROP TRIGGER IF EXISTS trigger_update_chat_stats_insert ON chat_messages;
CREATE TRIGGER trigger_update_chat_stats_insert
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_stats_on_message_change();

DROP TRIGGER IF EXISTS trigger_update_chat_stats_update ON chat_messages;
CREATE TRIGGER trigger_update_chat_stats_update
    AFTER UPDATE ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_stats_on_message_change();

DROP TRIGGER IF EXISTS trigger_update_chat_stats_delete ON chat_messages;
CREATE TRIGGER trigger_update_chat_stats_delete
    AFTER DELETE ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_stats_on_message_change();

-- Создаем триггеры для обновления чатов при изменении сообщений
CREATE OR REPLACE FUNCTION update_chat_on_message_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Обновляем информацию о последнем сообщении в чате
        UPDATE chats 
        SET last_message = NEW.content,
            last_message_time = NEW.created_at,
            is_read = false,
            updated_at = NOW()
        WHERE id = NEW.chat_id;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Если изменился статус прочтения, обновляем чат
        IF OLD.is_read != NEW.is_read THEN
            UPDATE chats 
            SET is_read = NEW.is_read,
                updated_at = NOW()
            WHERE id = NEW.chat_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- При удалении сообщения обновляем чат
        UPDATE chats 
        SET updated_at = NOW()
        WHERE id = OLD.chat_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггеры для автоматического обновления чатов
DROP TRIGGER IF EXISTS trigger_update_chat_on_message_insert ON chat_messages;
CREATE TRIGGER trigger_update_chat_on_message_insert
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_on_message_change();

DROP TRIGGER IF EXISTS trigger_update_chat_on_message_update ON chat_messages;
CREATE TRIGGER trigger_update_chat_on_message_update
    AFTER UPDATE ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_on_message_change();

DROP TRIGGER IF EXISTS trigger_update_chat_on_message_delete ON chat_messages;
CREATE TRIGGER trigger_update_chat_on_message_delete
    AFTER DELETE ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_on_message_change();

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
