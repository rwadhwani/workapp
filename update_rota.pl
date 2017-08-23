#!perl

require("includes/shared.pl");

print "Content-type:text/html\n\n";

$query = "select rota_id, total_hours, break_time from rota where total_hours > 4.25 and break_time > 0 order by rota_id";
print "$query<br><br>";
$query = $dbh->prepare($query);
$query->execute();
while ($data = $query->fetchrow_hashref) {
    $total_hours = $$data{total_hours};
    $total_hours -= $$data{break_time};
    print "ROTA [$$data{rota_id}]: ($$data{total_hours}) ($$data{break_time})<br>";
    
    $dbh->do("update rota set total_hours='$total_hours' where rota_id='$$data{rota_id}' limit 1");
    print "update rota set total_hours='$total_hours' where rota_id='$$data{rota_id}' <br><br>";
}

exit;