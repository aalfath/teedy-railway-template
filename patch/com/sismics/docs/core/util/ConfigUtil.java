package com.sismics.docs.core.util;

import com.sismics.docs.core.constant.ConfigType;
import com.sismics.docs.core.dao.ConfigDao;
import com.sismics.docs.core.model.jpa.Config;

import java.util.ResourceBundle;

/**
 * Configuration parameter utilities.
 *
 */
public class ConfigUtil {
    /**
     * Returns the textual value of a configuration parameter.
     *
     * @param configType Type of the configuration parameter
     * @return Textual value of the configuration parameter
     * @throws IllegalStateException Configuration parameter undefined
     */
    public static String getConfigStringValue(ConfigType configType) {
        // Railway template patch: background jobs (file processing) call this outside of a
        // transaction, with a closed EntityManager, so the lookup failed and callers fell back
        // to their default. That made the admin's "OCR enabled" switch a no-op for uploads.
        // Read the value in a short transaction of its own in that case.
        jakarta.persistence.EntityManager em = com.sismics.util.context.ThreadLocalContext.get().getEntityManager();
        if (em == null || !em.isOpen()) {
            java.util.concurrent.atomic.AtomicReference<Config> ref = new java.util.concurrent.atomic.AtomicReference<>();
            TransactionUtil.handle(() -> ref.set(new ConfigDao().getById(configType)));
            Config config = ref.get();
            if (config == null) {
                throw new IllegalStateException("Config parameter not found: " + configType);
            }
            return config.getValue();
        }

        ConfigDao configDao = new ConfigDao();
        Config config = configDao.getById(configType);
        if (config == null) {
            throw new IllegalStateException("Config parameter not found: " + configType);
        }
        return config.getValue();
    }

    /**
     * Returns the configuration resource bundle.
     *
     * @return Resource bundle
     */
    public static ResourceBundle getConfigBundle() {
        return ResourceBundle.getBundle("config");
    }

    /**
     * Returns the integer value of a configuration parameter.
     *
     * @param configType Type of the configuration parameter
     * @return Integer value of the configuration parameter
     * @throws IllegalStateException Configuration parameter undefined
     */
    public static int getConfigIntegerValue(ConfigType configType) {
        String value = getConfigStringValue(configType);

        return Integer.parseInt(value);
    }

    /**
     * Returns the long value of a configuration parameter.
     *
     * @param configType Type of the configuration parameter
     * @return Long value of the configuration parameter
     * @throws IllegalStateException Configuration parameter undefined
     */
    public static long getConfigLongValue(ConfigType configType) {
        String value = getConfigStringValue(configType);

        return Long.parseLong(value);
    }

    /**
     * Returns the boolean value of a configuration parameter.
     *
     * @param configType Type of the configuration parameter
     * @return Boolean value of the configuration parameter
     * @throws IllegalStateException Configuration parameter undefined
     */
    public static boolean getConfigBooleanValue(ConfigType configType) {
        String value = getConfigStringValue(configType);
        return Boolean.parseBoolean(value);
    }

    /**
     * Returns the boolean value of a configuration parameter with a default value.
     *
     * @param configType Type of the configuration parameter
     * @param defaultValue Default value to return if the configuration parameter is undefined
     * @return Boolean value of the configuration parameter
     */
    public static boolean getConfigBooleanValue(ConfigType configType, boolean defaultValue) {
        try {
            return getConfigBooleanValue(configType);
        } catch (IllegalStateException e) {
            return defaultValue;
        }
    }
}
