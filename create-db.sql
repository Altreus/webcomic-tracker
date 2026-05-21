CREATE TABLE comic (
    name TEXT PRIMARY KEY,
    feed_url TEXT
);

CREATE TABLE url (
    comic_name TEXT,
    url TEXT,
    pubdate TEXT, -- sqlite uses functions instead of first-class date types
    opened BOOL,
    FOREIGN KEY(comic_name) REFERENCES comic(name),
    UNIQUE(url)
);
