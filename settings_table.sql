-- Исправление функции get_library_posts - версия 2
-- Этот скрипт нужно выполнить в базе данных

-- Удаляем старую функцию
DROP FUNCTION IF EXISTS get_library_posts(UUID, UUID);

-- Создаем новую функцию с правильным порядком полей
CREATE OR REPLACE FUNCTION get_library_posts(library_uuid UUID, user_uuid UUID)
RETURNS TABLE(
    post_id UUID,
    author_id UUID,
    author_name VARCHAR(100),
    author_username VARCHAR(100),
    content TEXT,
    genre VARCHAR(50),
    hashtags TEXT[],
    links TEXT[],
    is_private BOOLEAN,
    allow_library_addition BOOLEAN,
    likes_count INTEGER,
    comments_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE,
    is_liked BOOLEAN,
    added_to_library_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.author_id,
        p.author_name,
        p.author_username,
        p.content,
        p.genre,
        p.hashtags,
        p.links,
        p.is_private,
        p.allow_library_addition,
        p.likes_count,
        p.comments_count,
        p.created_at,
        EXISTS(
            SELECT 1 FROM post_likes pl 
            WHERE pl.post_id = p.id AND pl.user_id = user_uuid
        ) as is_liked,
        lp.added_at as added_to_library_at
    FROM library_posts lp
    JOIN posts p ON lp.post_id = p.id
    WHERE lp.library_id = library_uuid
    ORDER BY lp.added_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Проверяем, что функция создана
SELECT 'Функция get_library_posts пересоздана успешно' as status;

-- Тестируем функцию (замените UUID на реальные)
-- SELECT * FROM get_library_posts('your-library-uuid', 'your-user-uuid') LIMIT 1;
