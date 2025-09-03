-- Исправление типов данных в функциях чата
-- Этот скрипт исправляет ошибки типов данных в оптимизированных функциях

-- Удаляем старые функции
DROP FUNCTION IF EXISTS get_user_chats_optimized(UUID);
DROP FUNCTION IF EXISTS get_chat_messages_optimized(UUID, INTEGER, INTEGER);

-- Создаем исправленные функции с правильными типами данных

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

-- Оптимизированный запрос для получения сообщений чата
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

-- Проверяем, что функции созданы корректно
SELECT 
    proname as function_name,
    proargnames as argument_names,
    proargtypes::regtype[] as argument_types,
    prorettype::regtype as return_type
FROM pg_proc 
WHERE proname IN ('get_user_chats_optimized', 'get_chat_messages_optimized')
ORDER BY proname;

-- Тестируем функции (закомментировано, так как требует реальных данных)
-- SELECT * FROM get_user_chats_optimized('your-user-id-here'::UUID);
-- SELECT * FROM get_chat_messages_optimized('your-chat-id-here'::UUID, 0, 10);
