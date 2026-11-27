-- Schema of the song catalog (specs/13-catalog-recommendations/contracts/catalog.md).
-- Identical in quipux-playlist-infra (compose/catalog-db/init.sql) and in the tests of the backend.
CREATE EXTENSION IF NOT EXISTS vector;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE TABLE IF NOT EXISTS catalog.song_embedding (
    id        uuid PRIMARY KEY,
    content   text NOT NULL,
    metadata  jsonb NOT NULL,
    embedding vector(768) NOT NULL
);
CREATE INDEX IF NOT EXISTS song_embedding_hnsw
    ON catalog.song_embedding USING hnsw (embedding vector_cosine_ops);
