-- Создание таблицы настроек конфиденциальности пользователей
CREATE TABLE IF NOT EXISTS user_privacy_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    show_genres BOOLEAN NOT NULL DEFAULT true,
    show_profile_stats BOOLEAN NOT NULL DEFAULT true,
    show_libraries BOOLEAN NOT NULL DEFAULT true,
    allow_messages_from_all BOOLEAN NOT NULL DEFAULT true,
    is_profile_hidden BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Создание индекса для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_user_privacy_settings_user_id ON user_privacy_settings(user_id);

-- Создание триггера для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_user_privacy_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_privacy_settings_updated_at
    BEFORE UPDATE ON user_privacy_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_user_privacy_settings_updated_at();

-- Комментарии к таблице и колонкам
COMMENT ON TABLE user_privacy_settings IS 'Настройки конфиденциальности пользователей';
COMMENT ON COLUMN user_privacy_settings.user_id IS 'ID пользователя';
COMMENT ON COLUMN user_privacy_settings.show_genres IS 'Показывать ли жанры пользователя';
COMMENT ON COLUMN user_privacy_settings.show_profile_stats IS 'Показывать ли статистику профиля';
COMMENT ON COLUMN user_privacy_settings.show_libraries IS 'Показывать ли библиотеки';
COMMENT ON COLUMN user_privacy_settings.allow_messages_from_all IS 'Разрешить сообщения от всех пользователей';
COMMENT ON COLUMN user_privacy_settings.is_profile_hidden IS 'Скрыт ли профиль (доступен только подписчикам)';
COMMENT ON COLUMN user_privacy_settings.created_at IS 'Дата создания настроек';
COMMENT ON COLUMN user_privacy_settings.updated_at IS 'Дата последнего обновления настроек';
