
use strict;
use warnings;
use diagnostics;

no lib '.';
use lib './src/lib';

use Text::Markup::Tester;
&run_test('./tests', $0);

