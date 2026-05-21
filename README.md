```
cpanm --installdeps .
sqlite3 comics.db < create-db.sql
./webcomic-reminder.pl -l http://\*:8080
```
