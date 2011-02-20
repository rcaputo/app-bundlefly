package Common;

# Common utilities.

use warnings;
use strict;

use CombinedGraph;

use CPANDB ();

use Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw( initialize_cpandb analyze_modules install_graph );

sub initialize_cpandb {
	CPANDB->import( { show_progress => 1 } );
}

sub analyze_modules {
	my $graph;
	my %seen;

	foreach my $module (@_) {
		my $m = eval { CPANDB::Module->load( $module ) };
		if ($@) {
			print "--- Module '$module' is not in the CPANDB.\n";
			next;
		}

		my $distribution = $m->distribution();
		print "+++ Module '$module' is part of distribution '$distribution'.\n";

		next if $seen{$distribution}++;

		my $d = eval { CPANDB->distribution( $distribution ) };
		if ($@) {
			my $msg = $@;
			$msg =~ s/\sat\s\S+\s*line\s*\d+.*$//s;
			print "--- $msg\n";
			next;
		}

		$graph = $d->_dependency( _class => 'CombinedGraph', perl => 999 );
	}

	return $graph;
}

### Install a grpah of modules to reduce forward dependencies.
#
# Avoids "prepend them to the queue", which causes distributions to be
# installed three or more times.  Also avoids a lot of prompts, which
# can prolong one's agony.

sub install_graph {
	my $graph = shift;

	while (scalar $graph->vertices()) {
		DISTRO: foreach my $distro ($graph->successorless_vertices()) {

			# Sort by length.  Most of the time the module with the shortest
			# name is the distribution's primary module.

			my @successorless_modules = (
				sort { length($a) <=> length($b) }
				CPANDB::Module->select( 'where distribution = ?', $distro)
			);

			my $module = $successorless_modules[0]->module;

			my $location = `perldoc -l $module 2> /dev/null`;
			if (defined $location and length $location) {
				chomp $location;
				if (-f $location) {
					print "Module $module already installed.\n";
					next DISTRO;
				}
			}

			print "Installing $module ...\n";

			if (system("cpan", $module)) {
				die(
					"\n",
					"***** Installation of $distro failed. Stopping.\n",
				);
			}
		}
		continue {
			$graph->delete_vertex($distro);
		}
	}
}

1;
