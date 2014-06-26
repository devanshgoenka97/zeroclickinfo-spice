package DDG::Spice::Domains;
# ABSTRACT: Returns an internet domain's availability and whois information.

use DDG::Spice;

# turns on/off debugging output
my $is_debug = 0;

# regex for allowed TLDS (grabbed from DDG core repo, in /lib/DDG/Util/Constants.pm)
my $tlds_qr = qr/(?:c(?:o(?:m|op)?|at?|[iykgdmnxruhcfzvl])|o(?:rg|m)|n(?:et?|a(?:me)?|[ucgozrfpil])|e(?:d?u|[gechstr])|i(?:n(?:t|fo)?|[stqldroem])|m(?:o(?:bi)?|u(?:seum)?|i?l|[mcyvtsqhaerngxzfpwkd])|g(?:ov|[glqeriabtshdfmuywnp])|b(?:iz?|[drovfhtaywmzjsgbenl])|t(?:r(?:avel)?|[ncmfzdvkopthjwg]|e?l)|k[iemygznhwrp]|s[jtvberindlucygkhaozm]|u[gymszka]|h[nmutkr]|r[owesu]|d[kmzoej]|a(?:e(?:ro)?|r(?:pa)?|[qofiumsgzlwcnxdt])|p(?:ro?|[sgnthfymakwle])|v[aegiucn]|l[sayuvikcbrt]|j(?:o(?:bs)?|[mep])|w[fs]|z[amw]|f[rijkom]|y[eut]|qa)/i;

# regex for parsing URLs
my $url_qr = qr/(?:http:\/\/)?([^\s\.]*\.)*([^\s\.]*?)\.($tlds_qr)(\:?[0-9]{1,4})?([^\s]*)/;

# additional keywords that trigger this spice
my $whois_keywords_qr = qr/whois|lookup|(?:is\s|)domain|(?:is\s|)available|register|owner(?:\sof|)|who\sowns|(?:how\sto\s|)buy/i;

# trigger this spice when either:
# - query contains only a URL
# - query contains starts or end with any of the whois keywords
#
# note that there are additional guards in the handle() function that
# narrow this spice's query space.
#
triggers query_raw =>
    qr/^$url_qr$/,
    qr/^$whois_keywords_qr|$whois_keywords_qr$/;

# API call details for Whois API (http://www.whoisxmlapi.com/)
spice to => 'https://www.whoisxmlapi.com/whoisserver/WhoisService?domainName=$1&outputFormat=JSON&callback={{callback}}&username={{ENV{DDG_SPICE_DOMAINS_USERNAME}}}&password={{ENV{DDG_SPICE_DOMAINS_PASSWORD}}}';

handle sub {
    my ($query) = @_;
    return if !$query; # do not trigger this spice if the query is blank

    # parse the URL into its parts
    my ($subdomains, $domain, $tld, $port, $resource_path) = $query =~ $url_qr; 

    # debugging output
    warn 'query: ', $query, "\t", 'sub: ', $subdomains || '', "\t", 'domain: ', $domain || '', "\t", 'tld: ', $tld || '', "\t", 'port: ', $port || '', "\t", 'resource path: ', $resource_path || '' if $is_debug;

    # get the non-URL text from the query by combining the text before and after the match
    my $non_url_text = $` . $'; #' <-- closing tick added for syntax highlighting

    # is the string a naked domain, i.e. is there any text besides the domain?
    my $is_naked_domain = trim($non_url_text) eq '';

    # skip if we're missing a domain or a tld
    return if !defined $domain || $domain eq '' || !defined $tld || $tld eq '';

    # skip if we have naked domain that contains a non-www subdomain, a port or a resource_path.
    # e.g. continue: 'http://duckduckgo.com' is allowed
    #      skip: 'http://blog.duckduckgo.com'
    #      skip: 'http://duckduckgo.com:8080'
    #      skip:  'http://blog.duckduckgo.com/hello.html'
    #
    # note that if the user includes a whois keyword to any of these,
    # such as 'whois http://blog.duckduckgo.com', they we continue.
    #
    # this signals to us that the user wants a whois result, and isn't just
    # trying to nav to the URL they typed.
    #
    return if $is_naked_domain
	&& ( (defined $subdomains && $subdomains !~ /^www.$/)
	     || (defined $port && $port ne '')
	     || (defined $resource_path && $resource_path ne ''));

    # return the combined domain + tld (after adding a period in between)
    return lc "$domain.$tld";
};

# Returns a string with leading and trailing spaces removed.
sub trim {
    my ($str) = @_;
    $str =~ s/^\s*(.*)?\s*$/$1/;
    return $str;
}

1;
