package CombinedGraph;

# Combine the dependency graph of all autobundled distributions.
# CPANDB::Distribution::_dependency() creates a new graph for each
# module.  We augment Graph::Directed's new() to return the same
# graph each time.

use warnings;
use strict;
use Graph::Directed;
use base qw(Graph::Directed);

my $singleton;

sub new {
	my $class = shift;
	$singleton = bless $class->SUPER::new(@_), $class unless $singleton;
	return $singleton;
}

1;
