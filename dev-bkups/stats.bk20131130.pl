#!perl

require("includes/shared.pl");

$template = &openFile("templates/template.html");
$content = &openFile("templates/$scriptname.html");
&initFunctions;

$dquery = $dbh->prepare("select DATE_FORMAT(CURRENT_DATE,' (%a, %d %b)') as currentdate");
$dquery->execute();
$ddata = $dquery->fetchrow_hashref;

$squery = $dbh->prepare("select app_name, current_employer, current_salary, currency from settings limit 1");
$squery->execute();
$sdata = $squery->fetchrow_hashref;
$current_employer = $$sdata{current_employer};
$content =~ s|<!--EMPLOYER-->|$current_employer|;
$content =~ s|<!--APP_NAME-->|$$sdata{app_name}|;

$query = $dbh->prepare("select rota_id, DATE_FORMAT(workdate,'%a, %d %b %Y') as work_date from rota where employer=\"$current_employer\" order by workdate ASC limit 1");
$query->execute();
$data = $query->fetchrow_hashref;
$content =~ s|<!--DATE_JOINED-->|<a href="$path/manage_rota?$$data{rota_id}">$$data{work_date}</a>|;

# NEXT
$query = $dbh->prepare("select rota_id, workdate, holiday, DATE_FORMAT(start_time,'%H:%i') as start_time, DATE_FORMAT(stop_time,'%H:%i') as stop_time, total_hours from rota where workdate=CURRENT_DATE and employer=\"$current_employer\" limit 1");
$query->execute();
$data = $query->fetchrow_hashref;
$$data{total_hours} =~ s|.00$||;
if ($$data{workdate} ne "") {
    if ($$data{holiday}) { $content =~ s|<!--TODAY-->|<a href="$path/manage_rota?$$data{rota_id}" class="green" style="display:block;">HOLIDAY ($$data{start_time} - $$data{stop_time}) - $$data{total_hours} hours</a>|; }
    else { $content =~ s|<!--TODAY-->|<a href="$path/manage_rota?$$data{rota_id}" class="green" style="display:block;">Working ($$data{start_time} - $$data{stop_time}) - $$data{total_hours} hours</a>|; }
} else { $content =~ s|<!--TODAY-->|<span class="red">Not working</span>|; }

$content =~ s|<!--CURRENT_DATE-->|$$ddata{currentdate}|;
$income_today = &getIncome("$$data{workdate}", "$$data{workdate}", "$$data{total_hours}");
if ($income_today > 0) { $content =~ s|<!--INCOME_TODAY-->|$$sdata{currency}$income_today|g; }
else { $content =~ s|<!--INCOME_TODAY-->|<span class="red">$$sdata{currency}$income_today</span>|g; }

# NEXT
# Note: Query skips the Holiday day
$query = $dbh->prepare("select rota_id, workdate, DATE_FORMAT(workdate,'%a, %d %b') as work_date, DATE_FORMAT(start_time,'%H:%i') as start_time, DATE_FORMAT(stop_time,'%H:%i') as stop_time, total_hours from rota where workdate > CURRENT_DATE and employer=\"$current_employer\" and holiday='0' ORDER BY workdate ASC limit 1");
$query->execute();
$data = $query->fetchrow_hashref;
$$data{total_hours} =~ s|.00$||;
if ($$data{work_date} ne "") { $content =~ s|<!--NEXT_WORKING_DAY-->|<a href="$path/manage_rota?$$data{rota_id}" style="display:block;">$$data{work_date} ($$data{start_time} - $$data{stop_time}) - $$data{total_hours} hours</a>|; }
else { $content =~ s|<!--NEXT_WORKING_DAY-->|<span class="red">Not available</span>|; }

$income_next_working_day = &getIncome("$$data{workdate}", "$$data{workdate}", "$$data{total_hours}");
$content =~ s|<!--INCOME_NEXT_WORKING_DAY-->|$$sdata{currency}$income_next_working_day|;

# NEXT
# Note: Query skips the Holiday day
$query = $dbh->prepare("select rota_id, workdate, DATE_FORMAT(workdate,'%a, %d %b') as work_date, DATE_FORMAT(start_time,'%H:%i') as start_time, DATE_FORMAT(stop_time,'%H:%i') as stop_time, total_hours from rota where workdate < CURRENT_DATE and employer=\"$current_employer\" and holiday='0' ORDER BY workdate DESC limit 1");
$query->execute();
$data = $query->fetchrow_hashref;
$$data{total_hours} =~ s|.00$||;
if ($$data{work_date} ne "") { $content =~ s|<!--LAST_WORKING_DAY-->|<a href="$path/manage_rota?$$data{rota_id}" style="display:block;">$$data{work_date} ($$data{start_time} - $$data{stop_time}) - $$data{total_hours} hours</a>|; }
else { $content =~ s|<!--LAST_WORKING_DAY-->|<span class="red">Not available</span>|; }

$income_last_working_day = &getIncome("$$data{workdate}", "$$data{workdate}", "$$data{total_hours}");
$content =~ s|<!--INCOME_LAST_WORKING_DAY-->|$$sdata{currency}$income_last_working_day|;

# NEXT
$query = $dbh->prepare("select MIN(workdate) as workdate_from, MAX(workdate) as workdate_to, count(workdate) as total_days, SUM(total_hours) as total_hours from rota where MONTH(workdate)=MONTH(CURRENT_DATE) and workdate <= CURRENT_DATE and employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{total_days} eq "0") { $total_days = "<span class=\"red\">0 days</span>"; }
else { $total_days = "$$data{total_days} days"; }
if ($$data{total_hours} eq "") { $total_hours = "<span class=\"red\">0 hours</span>"; }
else { $total_hours = "$$data{total_hours} hours"; }
$content =~ s|<!--DAYS_HOURS_WORKED-->|$total_days / $total_hours|;

$income_days_hours_worked = &getIncome("$$data{workdate_from}", "$$data{workdate_to}", "$$data{total_hours}");
if ($income_days_hours_worked > 0) { $content =~ s|<!--INCOME_DAYS_HOURS_WORKED-->|$$sdata{currency}$income_days_hours_worked|g; }
else { $content =~ s|<!--INCOME_DAYS_HOURS_WORKED-->|<span class="red">$$sdata{currency}$income_days_hours_worked</span>|g; }

# NEXT
$query = $dbh->prepare("select MIN(workdate) as workdate_from, MAX(workdate) as workdate_to, count(workdate) as total_days, SUM(total_hours) as total_hours from rota where MONTH(workdate)=MONTH(CURRENT_DATE) and employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{total_days} eq "0") { $total_days = "<span class=\"red\">0 days</span>"; }
else { $total_days = "$$data{total_days} days"; }
if ($$data{total_hours} eq "") { $total_hours = "<span class=\"red\">0 hours</span>"; }
else {
    #$avg_weekly = $$data{total_hours} / 4;
    #$avg_weekly = &makePrice($avg_weekly);
    #$total_hours = "$$data{total_hours} hours <span class=\"light-grey\">($avg_weekly hours weekly average)</span>";
    $total_hours = "$$data{total_hours} hours";
}
$content =~ s|<!--DAYS_HOURS_SCHEDULED-->|$total_days / $total_hours|;

$income_days_hours_scheduled = &getIncome("$$data{workdate_from}", "$$data{workdate_to}", "$$data{total_hours}");
if ($income_days_hours_scheduled > 0) { $content =~ s|<!--INCOME_DAYS_HOURS_SCHEDULED-->|$$sdata{currency}$income_days_hours_scheduled|g; }
else { $content =~ s|<!--INCOME_DAYS_HOURS_SCHEDULED-->|<span class="red">$$sdata{currency}$income_days_hours_scheduled</span>|g; }

# NEXT
$query = $dbh->prepare("select MIN(workdate) as workdate_from, MAX(workdate) as workdate_to, count(workdate) as total_days, SUM(total_hours) as total_hours from rota where MONTH(workdate)=MONTH(CURRENT_DATE - INTERVAL 1 MONTH) and employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{total_days} eq "0") { $total_days = "<span class=\"red\">0 days</span>"; }
else { $total_days = "$$data{total_days} days"; }
if ($$data{total_hours} eq "") { $total_hours = "<span class=\"red\">0 hours</span>"; }
else {
    #$avg_weekly = $$data{total_hours} / 4;
    #$avg_weekly = &makePrice($avg_weekly);
    #$total_hours = "$$data{total_hours} hours ($avg_weekly hours weekly average)";
    $total_hours = "$$data{total_hours} hours";
}
$content =~ s|<!--DAYS_HOURS_WORKED_LAST_MONTH-->|$total_days / $total_hours|;

$income_days_hours_worked_last_month = &getIncome("$$data{workdate_from}", "$$data{workdate_to}", "$$data{total_hours}");
if ($income_days_hours_worked_last_month > 0) { $content =~ s|<!--INCOME_DAYS_HOURS_WORKED_LAST_MONTH-->|$$sdata{currency}$income_days_hours_worked_last_month|g; }
else { $content =~ s|<!--INCOME_DAYS_HOURS_WORKED_LAST_MONTH-->|<span class="red">$$sdata{currency}$income_days_hours_worked_last_month</span>|g; }

# NEXT
$query = $dbh->prepare("select MIN(workdate) as workdate_from, MAX(workdate) as workdate_to, count(workdate) as total_days, SUM(total_hours) as total_hours from rota where YEAR(workdate)=YEAR(CURRENT_DATE) and employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{total_days} eq "0") { $total_days = "<span class=\"red\">0 days</span>"; }
else { $total_days = "$$data{total_days} days"; }
if ($$data{total_hours} eq "") { $total_hours = "<span class=\"red\">0 hours</span>"; }
else { $total_hours = "$$data{total_hours} hours"; }
$content =~ s|<!--DAYS_HOURS_WORKED_CURRENT_YEAR-->|$total_days / $total_hours|;


# ###########################################
# NEXT
$query = $dbh->prepare("select payslip_id, DATE_FORMAT(date,'%a, %d %b %Y') as pdate, net_payment from payslips where employer=\"$current_employer\" order by date DESC limit 1");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{net_payment} > 0) { $content =~ s|<!--LATEST_PAYSLIP-->|$$sdata{currency}$$data{net_payment} on <a href="$path/payslips?$$data{payslip_id}">$$data{pdate}</a>|; }
else { $content =~ s|<!--LATEST_PAYSLIP-->|<span class="red">Never</span>|; }

# NEXT
$query = $dbh->prepare("select SUM(net_payment) as net_payment from payslips where employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{net_payment} > 0) { $content =~ s|<!--PAYSLIP_TOTAL-->|$$sdata{currency}$$data{net_payment}</a>|; }
else { $content =~ s|<!--PAYSLIP_TOTAL-->|<span class="red">-</span>|; }
# ###########################################

# NEXT
$query = $dbh->prepare("select SUM(total_hours) as total_hours, MIN(workdate) as workdate_from, MAX(workdate) as workdate_to from rota where YEAR(workdate)=YEAR(CURRENT_DATE) and employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
$current_year_pay = &getIncome("$$data{workdate_from}", "$$data{workdate_to}", "$$data{total_hours}", "");
if ($current_year_pay > 0) { $content =~ s|<!--INCOME_CURRENT_YEAR-->|$$sdata{currency}$current_year_pay|g; }
else { $content =~ s|<!--INCOME_CURRENT_YEAR-->|<span class="red">$$sdata{currency}$current_year_pay</span>|g; }

# NEXT
$query = $dbh->prepare("select SUM(total_hours) as total_hours, MIN(workdate) as workdate_from, MAX(workdate) as workdate_to from rota where YEAR(workdate)=YEAR(CURRENT_DATE)-1 and employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
$last_year_pay = &getIncome("$$data{workdate_from}", "$$data{workdate_to}", "$$data{total_hours}");
if ($last_year_pay > 0) { $content =~ s|<!--INCOME_LAST_YEAR-->|$$sdata{currency}$last_year_pay|; }
else { $content =~ s|<!--INCOME_LAST_YEAR-->|<span class="red">$$sdata{currency}$last_year_pay</span>|; }

# NEXT
$query = $dbh->prepare("select SUM(total_hours) as total_hours, MIN(workdate) as workdate_from, MAX(workdate) as workdate_to from rota where employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
#$total_income = &getIncome("$$data{workdate_from}", "$$data{workdate_to}", "$$data{total_hours}", "", '1');
$total_income = $current_year_pay + $last_year_pay;
if ($total_income > 0) { $content =~ s|<!--INCOME_TOTAL-->|$$sdata{currency}$total_income|; }
else { $content =~ s|<!--INCOME_TOTAL-->|<span class="red">$$sdata{currency}$total_income</span>|; }

# NEXT
$query = $dbh->prepare("select SUM(directories) as total_directories from rota where employer=\"$current_employer\"");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{total_directories} > 0) { $content =~ s|<!--TOTAL_DIRECTORIES-->|$$data{total_directories}|; }
else { $content =~ s|<!--TOTAL_DIRECTORIES-->|<span class="red">0</span>|; }


# NEXT
$query = $dbh->prepare("select rate, per, DATE_FORMAT(since,'%d %b %Y') as date_since from account_settings where employer_name='$current_employer' order by since DESC");
$query->execute();
while ($data = $query->fetchrow_hashref) {
    $salaries .= "$$sdata{currency}$$data{rate} per/$$data{per} (Since $$data{date_since})<br />";
}
$content =~ s|<!--SALARY-->|$salaries|;

# NEXT
$query = $dbh->prepare("select rota_id, DATE_FORMAT(workdate,'%a, %d %b %Y') as workdate, DATE_FORMAT(start_time,'%H:%i') as start_time, DATE_FORMAT(stop_time,'%H:%i') as stop_time, employer, DATE_FORMAT(last_updated,'%a, %d %b %Y at %H:%i') as lastupdated from rota where employer=\"$current_employer\" order by last_updated DESC limit 1");
$query->execute();
$data = $query->fetchrow_hashref;
if ($$data{lastupdated} ne "") {
    $content =~ s|<!--DATA_LAST_UPDATED-->|$$data{lastupdated} for <a href="$path/manage_rota?$$data{rota_id}">$$data{employer} on $$data{workdate} ($$data{start_time} - $$data{stop_time})</a>|;
} else {
    $content =~ s|<!--DATA_LAST_UPDATED-->|<span class="red">Never</span>|;
}

$template =~ s|<!--CONTENT-->|$content|;

print "Content-type:text/html\n\n";
print $template;



# ##############################################################################################

sub getIncome {
    my ($workdate_from, $workdate_to, $total_hours, $employer, $alert) = @_;
    my ($iquery, $idata) = ("");
    $employer = ($employer eq "")?$current_employer:$employer;
    $total_income = 0.00;
    
    if ($workdate_from eq $workdate_to) {
        $rquery = $dbh->prepare("select bonus from rota where workdate='$workdate_from' and employer=\"$employer\" limit 1");       # query to get bonus for 'this' date
        $rquery->execute();
        $rdata = $rquery->fetchrow_hashref;
        
        $iquery = $dbh->prepare("select rate from account_settings where employer_name=\"$employer\" and since <= '$workdate_from' order by since DESC limit 1");
        $iquery->execute();
        $idata = $iquery->fetchrow_hashref;
        $total_income = ($total_hours * $$idata{rate}) + $$rdata{bonus};                    # get income + bonus for 'this' date
    } else {
        #$tmp_workdate_from = $workdate_from;
        #$tmp_workdate_to = $workdate_to;
        $dquery = "select DATEDIFF ('$workdate_to', '$workdate_from') as date_diff";
        $errmsg .= "$dquery<br>";
        $dquery = $dbh->prepare($dquery);
        $dquery->execute();
        $datediff = $dquery->fetchrow_hashref;
        $date_diff = $$datediff{date_diff};
        #$tmp_workdate_from =~ s|-||g;
        #$tmp_workdate_to =~ s|-||g;
        #$date_diff = $tmp_workdate_to - $tmp_workdate_from;
        
        foreach (0..$date_diff) {
            #$rquery = "select workdate, total_hours, bonus from rota where YEAR(workdate)=YEAR('$workdate_from') AND MONTH(workdate)=MONTH('$workdate_from') AND DAY(workdate)=DAY('$workdate_from')+$_ and employer=\"$employer\" limit 1";
            $rquery = "select workdate, total_hours, bonus from rota where YEAR(workdate)=YEAR('$workdate_from') AND workdate='$workdate_from' + INTERVAL $_ DAY and employer=\"$employer\" limit 1";
            if ($alert) { $errmsg .= "[$date_diff] [$workdate_to - $workdate_from]<br />$rquery<br />"; }
            $rquery = $dbh->prepare($rquery);        # limit 1 and no while loop = assuming you work only ONCE in a day (not twice e.g., 0900-1200 then again 1800-2100)
            $rquery->execute();
            $rdata = $rquery->fetchrow_hashref;
            if ($$rdata{workdate} ne "") {                          # if worked on 'this' date, then get 'rate' from account_settings
                $iquery = $dbh->prepare("select rate from account_settings where employer_name=\"$employer\" and since <= '$$rdata{workdate}' order by since DESC limit 1");
                $iquery->execute();
                $idata = $iquery->fetchrow_hashref;
                $total_income += ($$rdata{total_hours} * $$idata{rate}) + $$rdata{bonus};   # get income + bonus for 'this' date
            }
        }
        if ($alert) { &displayMsg(0, $errmsg); }
    }
    
    $total_income = &makePrice($total_income);
    return $total_income;
}