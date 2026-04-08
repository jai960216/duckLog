-- Add category column to catalog_items (per-item category)
ALTER TABLE catalog_items ADD COLUMN IF NOT EXISTS category TEXT;
