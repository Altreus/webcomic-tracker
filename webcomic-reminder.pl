#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use Mojo::Feed;
# Can't really render a Mojo::Date in the way I want, but DateTime is a
# bugger to parse a date into, so using both together seems fairly smooth
use Mojo::Date;
use DateTime;
use Mojo::SQLite;

my $sqlite = Mojo::SQLite->new('comics.db');

helper truncate_to_date => sub($c, $d) {
    my $dt = DateTime->from_epoch( epoch => Mojo::Date->new($d)->epoch );
    $dt->truncate( to => 'day' );
    $dt->rfc3339
};

helper local_date => sub($c, $d) {
    DateTime->from_epoch( epoch => Mojo::Date->new($d)->epoch )->strftime('%x') 
};

get '/' => sub ($c) {
    my $comics = $sqlite->db->query('SELECT * FROM comic');

    my %dates;
    while (my $comic = $comics->hash) {
        my $feed = Mojo::Feed->new( url => $comic->{feed_url} );
        $feed->entries->each(sub {
            $sqlite->db->query('INSERT OR IGNORE INTO url (comic_name, url, pubdate, opened) VALUES (?,?,?,?)',
                $comic->{name}, $_->id, Mojo::Date->new($_->published)->to_datetime, 0
            );
        });

        # Don't break if for some reason no entries get added from the feed
        my $latest_entry = latest_entry_for($comic->{name}) or next;
        my $last_read    = last_read_for($comic->{name});

        push $dates{$c->truncate_to_date( $latest_entry->{pubdate} )}->{comics}->@*,
            { name => $comic->{name}, last_read => $last_read ? $c->local_date($last_read->{pubdate}) : 'never' };
    }

    $c->stash( dates => \%dates );
    $c->render(template => 'index');
};

get '/goto' => sub ($c) {
    my $last_read = last_read_for($c->param('comic'));
    unless ($last_read) {
        $last_read = first_entry_for($c->param('comic'));
    }

    # Set everything currently in the DB as opened.
    $sqlite->db->query(<<~'SQL', $c->param('comic'));
        UPDATE url SET opened = 1 WHERE comic_name = ?
        SQL

    # Redirect to the last-opened URL
    $c->redirect_to($last_read->{url});
};

sub latest_entry_for($comic_name) {
    my $q = $sqlite->db->query(<<~'SQL', $comic_name);
        SELECT * FROM url
        WHERE comic_name = ?
        ORDER BY datetime(pubdate) DESC
        LIMIT 1
        SQL
    my $latest_entry = $q->hash;

    return $latest_entry;
}

sub last_read_for($comic_name) {
    my $q = $sqlite->db->query(<<~'SQL', $comic_name);
        SELECT * FROM url
        WHERE comic_name = ?
        AND opened = 1
        ORDER BY datetime(pubdate) DESC
        LIMIT 1
        SQL
    my $last_read = $q->hash;

    return $last_read;
}

sub first_entry_for($comic_name) {
    my $q = $sqlite->db->query(<<~'SQL', $comic_name);
        SELECT * FROM url
        WHERE comic_name = ?
        ORDER BY datetime(pubdate) ASC LIMIT 1
        SQL
    return $q->hash;
}

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<% for my $d (reverse sort keys %$dates) { %>
    <h2><%= $c->local_date( $d ) %></h2>
    <% for my $comic ($dates->{$d}->{comics}->@*) { %>
        <p><a href="/goto?comic=<%= $comic->{name} %>" target="_blank">
            <%= $comic->{name} %></a> Last read: <%= $comic->{last_read} %>
        </p>
    <% } %>
<% } %>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
