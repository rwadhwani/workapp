#!perl

$path = "/workapp";
$DEFAULT_APPNAME = "Workapp";
$template = "";
$content = "";

$scriptname = $ENV{'SCRIPT_NAME'};
$scriptname =~ s|^$path||;
$scriptname =~ s|^/||;
$DEFAULT_CURRENCY = "£";

&connectToSQL;
&decodeForm;

sub initFunctions {
    $template =~ s|!path!|$path|g;
    $content =~ s|!path!|$path|g;
    if ($heading eq "") {
        $heading = ucfirst($scriptname);
        $heading =~ s|_| |g;
    }
    if ($page_title eq "") { $page_title = $heading; }
    $template =~ s|<title>(.*?)</title>|<title>$1 - $page_title</title>|;       # update page title
    &getAppName;
    &activeMenu;
}

sub getAppName {
    my ($query, $adata) = ("");
    $query = $dbh->prepare("select app_name from settings limit 1");
    $query->execute();
    $adata = $query->fetchrow_hashref;
    if ($$adata{app_name} eq "") { $$adata{app_name} = $DEFAULT_APPNAME; }      # get App name from settings or use default
    $template =~ s|<!--\[app_name\]-->|$$adata{app_name}|g;
}

sub activeMenu {
    my $menuID = @_[0];
    if ($menuID ne "") { $template =~ s|<li><a href="(.*/$menuID)" class="active"|<li><a href="$1"|; }
    else { $menuID = $scriptname; }
    $template =~ s|<li><a href="(.*/$menuID)"|<li><a href="$1" class="active"|;
}

sub connectToSQL {
    use DBI;
    $dbh = DBI->connect("DBI:mysql:workapp:localhost", "rajalavi", "laviraja24");
}

sub decodeForm {
	(*fval) = @_ if @_ ;

	if ( $ENV{'PATH_INFO'} ) {
		@path_info = split( "/", $ENV{'PATH_INFO'}); #as $ENV{'PATH_INFO'} begins with / (eg /LONDON/SOUTHEASTLONDON)
		#so when split the first item is blank any way - so $x can start at 1!
		
		$FORM{'mode'} = $path_info[1];
		$FORM{ $mode_key{ $path_info[1] } } = $path_info[2];
	}
	local ($buf);
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		read(STDIN,$buf,$ENV{'CONTENT_LENGTH'});
	}else {
		$buf=$ENV{'QUERY_STRING'};
	}
	if ($buf eq "") {
			return 0 ;
	}
	else {
 		@fval=split(/&/,$buf);
		foreach $i (0 .. $#fval) {
			($name,$val)=split (/=/,$fval[$i],2);
			$val=~tr/+/ /;
			$val=~ s/%(..)/pack("c",hex($1))/ge;
			$name=~tr/+/ /;
			$name=~ s/%(..)/pack("c",hex($1))/ge;
			if (!$val){ next; }		#ie if empty (if we dont do this, a multiple named field will become something like ",,,"
			if (!defined($FORM{$name})) {
				$FORM{$name}=$val;
			}
			else {
				$FORM{$name} .= ",$val";
				
				#if you want multi-selects to goto into an array change to:
				#$FORM{$name} .= "\0$val";
			}
		}
	}
	return 1;
}

sub openFile {
        local($filepath) = @_;
        if ( !(-e $filepath) ) { return "$filepath - File doesn't exist"; }
        $/ = undef;
        open( THEFILE, $filepath ) || die ( "Can't open $thefile" );
        $bigscalar = <THEFILE>;
        close( THEFILE );

        $/ = "\n";
        return $bigscalar;
}

sub formatText {
    my $text = @_[0];
    $text =~ s|"|'|g;
    return $text;
}

sub displayMsg {
# This function takes message type (0=info 1=error, and message to display on the page
# Usage:	&displayMsg(0,"Message to display");
#
	my ($type, $msg) = @_;
	if ($type == 1) {
		$template =~ s|id="info_msg">|id="error_msg" style="display:block;">$msg|;
	} else {
		$template =~ s|id="info_msg">|id="info_msg" style="display:block;">$msg|;
	}
}

sub getEmployersList {
    my ($query, $data, $elist) = ("");
    
    $query = $dbh->prepare("select employer_name from employers order by employer_name");
    $query->execute();
    while ($data = $query->fetchrow_hashref) {
        $elist .= "<option value=\"$$data{employer_name}\">$$data{employer_name}</option>\n         ";
    }
    return $elist;
}

sub makePrice {
    my $price = @_[0];
    $price = sprintf("%.2f", $price);
    return $price;
}

sub getLocaltime {
    (undef, $lmin, $lhour, $lday, $lmonth, $lyear, undef, undef, undef) = localtime(time);
    #$lmin = ($lmin < 10 && $lmin !~ /^0/)?"0".$lmin:$lmin;
    #$lhour = ($lhour < 10 && $lhour !~ /^0/)?"0".$lhour:$lhour;
    $lday = ($lday < 10 && $lday !~ /^0/)?"0".$lday:$lday;
    $lmonth += 1;
    $lmonth = ($lmonth < 10 && $lmonth !~ /^0/)?"0".$lmonth:$lmonth;
    $lyear += 1900;
}

1;