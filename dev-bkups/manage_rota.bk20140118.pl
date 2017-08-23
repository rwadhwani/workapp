#!perl

require("includes/shared.pl");

$template = &openFile("templates/template.html");
$content = &openFile("templates/$scriptname.html");
&initFunctions;

if ($ENV{'REQUEST_METHOD'} eq "POST") {
    if ($FORM{action} eq "delete") {
        $dquery = $dbh->prepare("delete from rota where rota_id='$FORM{rota_id}' limit 1");
        $dquery->execute();
        $drows = $dquery->rows();
        if ($drows > 0) {
            &displayMsg(1, "Rota [$FORM{rota_id}] deleted successfully!");
            print "Location:$path/rota\n\n";
        }
        $FORM{rota_id} = "";
    } else {
        &addUpdateRota;
    }
}

@sfields = ("employer");
@ifields = ("rota_id", "workdate", "start_time", "stop_time", "total_hours", "venue", "bonus", "directories", "break_time");
@tfields = ("notes");
@rfields = ("holiday");
$elist = &getEmployersList;
$content =~ s|<!--EMPLOYERS_LIST-->|$elist|;

if (($ENV{'QUERY_STRING'} =~ /^(\d{1,})$/ || $FORM{rota_id} =~ /^(\d{1,})$/) && ($FORM{action} ne "delete")) {
    # UPDATE EXISTING ROTA
    $rota_id = $1;
    $query = $dbh->prepare("select *, workdate as work_date, DATE_FORMAT(workdate,'%d/%m/%Y') as workdate, DATE_FORMAT(start_time,'%H:%i') as start_time, DATE_FORMAT(stop_time,'%H:%i') as stop_time from rota where rota_id='$rota_id' limit 1");
    $query->execute();
    $data = $query->fetchrow_hashref;
    $content =~ s|Current salary|Salary|;
    $content =~ s|ADD|UPDATE|;
    $$data{bonus} = ($$data{bonus} eq '0.00' || $$data{bonus} < 0.01)?"":$$data{bonus};
    $$data{bonus} =~ s|0{1,2}$||;
    $$data{bonus} =~ s|\.$||;
    $$data{total_hours} =~ s|0{1,2}$||;
    $$data{total_hours} =~ s|\.$||;
    $$data{total_hours} .= " hours";
    foreach (@sfields) { $content =~ s|<option value="$$data{$_}">|<option value="$$data{$_}" selected="selected">|; }
    foreach (@ifields) { $content =~ s|name="$_" value=".*?"|name="$_" value="$$data{$_}"|; }
    foreach (@tfields) { $$data{$_} =~ s|[\r\n][\r\n]|\n|g; $content =~ s|<textarea name="$_"(.*?)>|<textarea name="$_"$1>$$data{$_}|; }
    foreach (@rfields) { $content =~ s|name="$_" value="$$data{$_}"|name="$_" value="$$data{$_}" checked="checked"|; }
    
    # get salary per/hour for this DATE from account_settings
    $squery = $dbh->prepare("select rate from account_settings where since <= '$$data{work_date}' order by since DESC");
    $squery->execute();
    $sdata = $squery->fetchrow_hashref;
    $content =~ s|name="salary" value=""|name="salary" value="&pound;$$sdata{rate}"|;
} else {
    # ADD NEW ROTA
    $squery = $dbh->prepare("select current_employer, current_salary, current_venue, currency from settings limit 1");       # load current employer, salary and venue from settings to pre-select
    $squery->execute();
    $sdata = $squery->fetchrow_hashref;
    $content =~ s|<option value="$$sdata{current_employer}">|<option value="$$sdata{current_employer}" selected="selected">|;
    $content =~ s|name="salary" value=""|name="salary" value="$$sdata{currency}$$sdata{current_salary}"|;
    $content =~ s|name="venue" value=""|name="venue" value="$$sdata{current_venue}"|;
    $content =~ s|<!--BEGIN_TOTAL_HOURS-->.*?<!--END_TOTAL_HOURS-->||s;
    $content =~ s|<!--BEGIN_DELETE-->.*?<!--END_DELETE-->||;
    $content =~ s|name="holiday" value="0"|name="holiday" value="0" checked="checked"|;
    
    if ($FORM{date} ne "") { $content =~ s|name="workdate" value=""|name="workdate" value="$FORM{date}"|; }
}

$template =~ s|<!--CONTENT-->|$content|;

print "Content-type:text/html\n\n";
print $template;


sub addUpdateRota {
    $error = 0;
    $rota_id = $FORM{rota_id};
    $employer = $FORM{employer};
    $workdate = &formatText($FORM{workdate});
    $start_time = &formatText($FORM{start_time});
    $stop_time = &formatText($FORM{stop_time});
    $holiday = ($FORM{holiday} eq '1')?$FORM{holiday}:0;
    #$total_hours = $FORM{total_hours};
    $venue = &formatText($FORM{venue});
    $bonus = &formatText($FORM{bonus});
    $directories = &formatText($FORM{directories});
    $break_time = &formatText($FORM{break_time});
    $notes = &formatText($FORM{notes});
    
    if ($workdate =~ /^(\d{2}).(\d{2}).(\d{4})$/) {
        $workdate = $3."-".$2."-".$1;                       # convert the user date to yyyy-mm-dd format
        if ($start_time =~ /^(\d{2}).(\d{2})/) {
            $start_hh = $1;
            $start_mm = $2;
            $start_time = $start_hh.":".$start_mm;
            $starttime = $start_hh + ($start_mm / 60);
        } else { $error = 1; }
        if ($stop_time =~ /^(\d{2}).(\d{2})/) {
            $stop_hh = $1;
            $stop_mm = $2;
            $stop_time = $stop_hh.":".$stop_mm;
            $stoptime = $stop_hh + ($stop_mm / 60);
        } else { $error = 1; }
    } else { $error = 1; }
    
    if (!$error) {                                          # no error
        $total_hours = $stoptime - $starttime;
        if ($rota_id eq "") {                               # add new rota
            $query = $dbh->prepare("insert into rota (workdate, start_time, stop_time, holiday, total_hours, employer, venue, bonus, directories, break_time, notes) values ('$workdate', '$start_time', '$stop_time', '$holiday', '$total_hours', \"$employer\", \"$venue\", '$bonus', '$directories', '$break_time', \"$notes\")");
            $query->execute();
            $rows = $query->rows();
            if ($rows > 0) {
                &displayMsg(0, "Rota added.");
                print "Location:$path/rota\n\n";
            } else {
                &displayMsg(1, "Failed to add rota!");
                &preserveFormData;
            }
        } else {                                            # update existing rota
            $query = $dbh->prepare("update rota set workdate='$workdate', start_time='$start_time', stop_time='$stop_time', holiday='$holiday', total_hours='$total_hours', employer=\"$employer\", venue=\"$venue\", bonus='$bonus', directories='$directories', break_time='$break_time', notes=\"$notes\" where rota_id='$rota_id' limit 1");
            $query->execute();
            $rows = $query->rows();
            if ($rows > 0) {
                &displayMsg(0, "Rota updated.");
                print "Location:$path/rota\n\n";
            } else {
                &displayMsg(1, "Failed to update rota!");
                &preserveFormData;
            }
        }
    } else {
        if ($rota_id eq "") { &displayMsg(1, "Failed to add rota! Check date/time format."); }  # add new rota failed!
        else { &displayMsg(1, "Update failed! Check date/time format."); }                      # update rota failed!
        &preserveFormData;
    }
}

sub preserveFormData {
    foreach (@sfields) { $tmpval="\$$_"; $tmpval=eval($tmpval); $content =~ s|<option value="$tmpval">|<option value="$tmpval" selected="selected">|; }
    foreach (@ifields) { $tmpval="\$$_"; $tmpval=eval($tmpval); $content =~ s|name="$_" value=".*?"|name="$_" value="$tmpval"|; }
    foreach (@tfields) { $tmpval="\$$_"; $tmpval=eval($tmpval); $content =~ s|<textarea name="$_"(.*?)>|<textarea name="$tmpval"$1>$tmpval|; }
    foreach (@rfields) { $tmpval="\$$_"; $tmpval=eval($tmpval); $content =~ s|name="$_" value="$tmpval"|name="$_" value="$tmpval" checked="checked"|; }
}