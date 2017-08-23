#!perl

require("includes/shared.pl");

$query = $dbh->prepare("select startup_page from settings limit 1");        # read 'startup_page' settings and redirect the user
$query->execute();
$data = $query->fetchrow_hashref;

if ($ENV{QUERY_STRING} eq "" && $$data{startup_page} ne "") {               # having any params in query_string e.g., ?show will not redirect user
    print "Location:$path/$$data{startup_page}\n\n";
} else {
    $template = &openFile("templates/template.html");
    #$content  = &openFile("templates/home.html");
    $content = "This page is under development!";
    
    &initFunctions;
    $template =~ s|<!--CONTENT-->|$content|;

    print "Content-type:text/html\n\n";
    print $template;
}