-- hype-vendingmachine
-- Run once on the server database. Safe to re-run: every statement skips what already exists.
-- Requires MySQL 5.7+ or MariaDB 10.2+ (JSON columns).

-- Machines placed in the world. Owner preferences (schedule, alerts, payment methods) live in `settings`
CREATE TABLE IF NOT EXISTS `hype_vending_machines` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `description` VARCHAR(120) NOT NULL DEFAULT '',
    `model` VARCHAR(64) NOT NULL,
    `area` VARCHAR(64) NOT NULL DEFAULT '',
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    -- Framework identifier (citizenid / identifier). NULL while the machine is for sale
    `owner` VARCHAR(64) DEFAULT NULL,
    -- Cached so admin lists don't have to resolve offline players
    `owner_name` VARCHAR(64) DEFAULT NULL,
    `for_sale` TINYINT(1) NOT NULL DEFAULT 1,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `capacity` SMALLINT UNSIGNED NOT NULL DEFAULT 50,
    -- open / closed is set by the owner, disabled only by an admin
    `status` ENUM('open', 'closed', 'disabled') NOT NULL DEFAULT 'closed',
    `balance` INT UNSIGNED NOT NULL DEFAULT 0,
    `color_slot` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `settings` JSON DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Products a machine sells, with the owner's price and current stock. `item` matches the inventory item name
CREATE TABLE IF NOT EXISTS `hype_vending_products` (
    `machine_id` INT UNSIGNED NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `stock` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `sold` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`machine_id`, `item`),
    CONSTRAINT `fk_hype_vending_products_machine` FOREIGN KEY (`machine_id`) REFERENCES `hype_vending_machines` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every purchase. Daily revenue and sales charts are grouped from this table
CREATE TABLE IF NOT EXISTS `hype_vending_transactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `machine_id` INT UNSIGNED NOT NULL,
    `buyer` VARCHAR(64) NOT NULL,
    `buyer_name` VARCHAR(64) NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `quantity` SMALLINT UNSIGNED NOT NULL,
    `total` INT UNSIGNED NOT NULL,
    `payment` ENUM('cash', 'bank') NOT NULL DEFAULT 'cash',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_machine_time` (`machine_id`, `created_at`),
    CONSTRAINT `fk_hype_vending_transactions_machine` FOREIGN KEY (`machine_id`) REFERENCES `hype_vending_machines` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Deposits, withdrawals and stock order payments made from the machine balance
CREATE TABLE IF NOT EXISTS `hype_vending_cash` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `machine_id` INT UNSIGNED NOT NULL,
    `type` ENUM('deposit', 'withdraw', 'order') NOT NULL,
    `amount` INT UNSIGNED NOT NULL,
    `by` VARCHAR(64) NOT NULL,
    `by_name` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_machine_time` (`machine_id`, `created_at`),
    CONSTRAINT `fk_hype_vending_cash_machine` FOREIGN KEY (`machine_id`) REFERENCES `hype_vending_machines` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Supplier orders. Stock is added to the machine only when the status reaches `completed`
CREATE TABLE IF NOT EXISTS `hype_vending_orders` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `machine_id` INT UNSIGNED NOT NULL,
    `total` INT UNSIGNED NOT NULL,
    `status` ENUM('preparing', 'prepared', 'shipping', 'completed') NOT NULL DEFAULT 'preparing',
    `ordered_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_machine_status` (`machine_id`, `status`),
    CONSTRAINT `fk_hype_vending_orders_machine` FOREIGN KEY (`machine_id`) REFERENCES `hype_vending_machines` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Wholesale price is stored per line so later config changes don't rewrite old orders
CREATE TABLE IF NOT EXISTS `hype_vending_order_items` (
    `order_id` INT UNSIGNED NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `quantity` SMALLINT UNSIGNED NOT NULL,
    `unit_price` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`order_id`, `item`),
    CONSTRAINT `fk_hype_vending_order_items_order` FOREIGN KEY (`order_id`) REFERENCES `hype_vending_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Employees hired by the owner. A player can be staff only once per machine
CREATE TABLE IF NOT EXISTS `hype_vending_staff` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `machine_id` INT UNSIGNED NOT NULL,
    `identifier` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    -- JSON array of `section.action` strings (e.g. ["restock.order", "cash.deposit"]), so new permissions need no schema change
    `permissions` JSON NOT NULL,
    `hired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Updated each time the employee opens the owner panel. NULL until the first time
    `last_online` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_machine_identifier` (`machine_id`, `identifier`),
    KEY `idx_identifier` (`identifier`),
    CONSTRAINT `fk_hype_vending_staff_machine` FOREIGN KEY (`machine_id`) REFERENCES `hype_vending_machines` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Global settings edited from the admin panel, one JSON value per key
CREATE TABLE IF NOT EXISTS `hype_vending_settings` (
    `key` VARCHAR(64) NOT NULL,
    `value` JSON NOT NULL,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `hype_vending_settings` (`key`, `value`) VALUES
    ('wholesaleMultiplier', '1'),
    ('salesTax', '8'),
    ('maxMachinesPerPlayer', '3'),
    ('deliveryMinutes', '5'),
    ('defaultCapacity', '50'),
    ('defaultPrice', '20000'),
    ('allowPlayerPurchase', 'true'),
    ('webhook', '""'),
    ('logPurchases', 'true'),
    ('logAdminActions', 'true');
