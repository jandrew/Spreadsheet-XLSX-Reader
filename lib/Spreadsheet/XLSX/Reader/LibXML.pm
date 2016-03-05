package Spreadsheet::XLSX::Reader::LibXML;
use version 0.77; our $VERSION = version->declare('v0.40_3');
###LogSD	warn "You uncovered internal logging statements for Spreadsheet::XLSX::Reader::LibXML-$VERSION";

use 5.010;
use	Moose;
use	MooseX::StrictConstructor;
use	MooseX::HasDefaults::RO;
use Types::Standard qw( is_HashRef is_Object );
use Clone 'clone';
use Data::Dumper;

###LogSD use Log::Shiras::Telephone;
use lib	'../../../../lib',;
###LogSD use Log::Shiras::UnhideDebug;
use Spreadsheet::XLSX::Reader::LibXML::Error;
use Spreadsheet::XLSX::Reader::LibXML::FmtDefault;
###LogSD use Log::Shiras::UnhideDebug;
use Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings;
use Spreadsheet::XLSX::Reader::LibXML::FormatInterface;
use Spreadsheet::XLSX::Reader::LibXML::Workbook;
###LogSD with 'Log::Shiras::LogSpace';
use	MooseX::ShortCut::BuildInstance 1.032 qw( build_instance );

#########1 Dispatch Tables and data     4#########5#########6#########7#########8#########9

my	$attribute_defaults ={
		error_inst =>{
			package => 'ErrorInstance',
			superclasses => ['Spreadsheet::XLSX::Reader::LibXML::Error'],
			should_warn => 0,
		},
		formatter_inst =>{
			package => 'FormatInstance',
			superclasses => ['Spreadsheet::XLSX::Reader::LibXML::FmtDefault'],
			add_roles_in_sequence =>[qw(
				Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings
				Spreadsheet::XLSX::Reader::LibXML::FormatInterface
			)],
		},
		sheet_parser		=> 'reader',
		count_from_zero		=> 1,
		file_boundary_flags	=> 1,
		empty_is_end		=> 0,
		values_only			=> 0,
		from_the_edge		=> 1,
		group_return_type	=> 'instance',
		empty_return_type	=> 'empty_string',
		cache_positions	=>{# Test this !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			shared_strings_interface => 5242880,# 5 MB
			styles_interface => 5242880,# 5 MB
			#~ worksheet_interface => 5242880,# 5 MB #Not yet available
			#~ chartsheet_interface => 5242880,# 5 MB
		},
	};
my	$flag_settings ={
		alt_default =>{
			values_only       => 1,
			count_from_zero   => 0,
			empty_is_end      => 1,
		},
		just_the_data =>{
			count_from_zero   => 0,
			values_only       => 1,
			empty_is_end      => 1,
			group_return_type => 'value',
			from_the_edge     => 0,
			empty_return_type => 'undef_string',
		},
		just_raw_data =>{
			count_from_zero   => 0,
			values_only       => 1,
			empty_is_end      => 1,
			group_return_type => 'unformatted',
			from_the_edge     => 0,
			empty_return_type => 'undef_string',
		},
		like_ParseExcel =>{
			count_from_zero => 1,
			group_return_type => 'instance',
		},
		debug =>{
			error_inst =>{
				superclasses => ['Spreadsheet::XLSX::Reader::LibXML::Error'],
				package => 'ErrorInstance',
				should_warn => 1,
			},
			show_sub_file_size => 1,
		},
		lots_of_ram =>{ #Estimated to consume 4+ Gig of ram when the file is loaded and processed!!!!!!!!!!
			cache_positions	=>{
				shared_strings_interface => 209715200,# 200 MB
				styles_interface => 209715200,# 200 MB
				#~ worksheet_interface => 209715200,# 200 MB #Not yet available
				#~ chartsheet_interface => 209715200,# 200 MB
			},
		},
		big_file =>{ #Estimated to consume 4+ Gig of ram when the file is loaded and processed!!!!!!!!!!
			cache_positions	=>{
				shared_strings_interface => 10240,# 10 KB
				styles_interface => 10240,# 10 KB
				#~ worksheet_interface => 10240,# 10 KB #Not yet available
				#~ chartsheet_interface => 10240,# 10 KB
			},
		},
	};
my $delay_till_build = [qw( formatter_inst )];

#########1 Public Methods     3#########4#########5#########6#########7#########8#########9

###LogSD sub get_class_space{ 'Top' }

sub import{# Flags handled here!
    my ( $self, @flag_list ) = @_;
	#~ print "Made it to import\n";
	if( scalar( @flag_list ) ){
		for my $flag ( @flag_list ){
			#~ print "Arrived at import with flag: $flag\n";
			if( $flag =~ /^:(\w*)$/ ){# Handle text based flags
				my $default_choice = $1;
				print "Attempting to change the default group type to: $default_choice\n";
				if( exists $flag_settings->{$default_choice} ){
					for my $attribute ( keys %{$flag_settings->{$default_choice}} ){
						#~ print "Changing flag -$attribute- to:" . Dumper( $flag_settings->{$default_choice}->{$attribute} );
						$attribute_defaults->{$attribute} = $flag_settings->{$default_choice}->{$attribute};
					}
				}else{
					confess "No settings available for the flag: $flag";
				}
			}elsif( $flag =~ /^v?\d+\.?\d*/ ){# Version check may wind up here
				#~ print "Running version check on version: $flag\n";
				my $result = $VERSION <=> version->parse( $flag );
				#~ print "Tested against version -$VERSION- gives result: $result\n";
				if( $result < 0 ){
					confess "Version -$flag- required - the installed version is: $VERSION";
				}
			}else{
				confess "Passed attribute default flag -$flag- does not comply with the correct format";
			}
		}
	}
	#~ print "Finished import\n";
}

#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has _workbook =>(
	isa			=> 'Spreadsheet::XLSX::Reader::LibXML::Workbook',
	predicate	=> '_has_workbook',
	writer		=> '_set_workbook',
	clearer		=> '_clear_the_workbook',
	handles		=>
		qr/^(?!(				# Negative look ahead blocking most Moose shared methods
			BUILD|
			BUILDARGS|
			DESTROY|
			DEMOLISH|
			new|
			get_all_space|		# Also blocking common logging methods 
			get_class_space|	# (Where ###LogSD has activeded them)
			get_log_space|
			has_log_space|
			set_log_space
		))[^\s]+/x,				#Ensure somthing follows the negative look-ahead
);

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9
#########1 For purposes of garbage collection cleanup this is all this module does #######9

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
	my %args = is_HashRef( $args[0] ) ? %{$args[0]} : @args;
	###LogSD	$args{log_space} //= 'XLSX';
	###LogSD	my	$class_space = __PACKAGE__->get_class_space;
	###LogSD	my	$log_space = $args{log_space} . "::$class_space" . '::_hidden::BUILDARGS';
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space => $log_space, );
	###LogSD		$phone->talk( level => 'trace', message =>[
	###LogSD			'Arrived at BUILDARGS with: ', @args ] );
	
	# Handle depricated cache_positions
	#~ print longmess( Dumper( %args ) );
	if( exists $args{cache_positions} ){
		###LogSD	$phone->talk( level => 'trace', message =>[
		###LogSD		"The user did pass a value to cache_positions as:", $args{cache_positions}] );
		if( !is_HashRef( $args{cache_positions} ) ){
			warn "Passing a boolean value to the attribute 'cache_positions' is depricated since v0.40.2 - the input will be converted per the documentation";
			$args{cache_positions} = !$args{cache_positions} ?
				$flag_settings->{big_file}->{cache_positions} : 
				$attribute_defaults->{cache_positions};
		}
		
		#scrub cache_positions
		for my $passed_key ( keys %{$args{cache_positions}} ){
			if( !exists $attribute_defaults->{cache_positions}->{$passed_key} ){
				warn "Passing a cache position for '$passed_key' but that is not allowed";
			}
		}
		for my $stored_key ( keys %{$attribute_defaults->{cache_positions}} ){
			if( !exists $args{cache_positions}->{$stored_key} ){
				warn "Passed cache positions are missing key => values for key: $stored_key";
			}
		}
	}
		
	# Add any defaults
	###LogSD	$phone->talk( level => 'trace', message =>[
	###LogSD		"Processing possible default values", $attribute_defaults ] );
	for my $key ( keys %$attribute_defaults ){
		###LogSD	$phone->talk( level => 'trace', message =>[
		###LogSD		"Processing possible default for -$key- with value:", $attribute_defaults->{$key} ] );
		if( exists $args{$key} ){
			###LogSD	$phone->talk( level => 'trace', message =>[
			###LogSD		"Found user defined -$key- with value(s): ", $args{$key} ] );
		}else{
			###LogSD	$phone->talk( level => 'trace', message =>[
			###LogSD		"Setting default -$key- with value(s): ", $attribute_defaults->{$key} ] );
			$args{$key} = clone( $attribute_defaults->{$key} );
		}
	}
	
	# Build object instances as needed
	for my $key ( keys %args ){
		###LogSD	$phone->talk( level => 'trace', message =>[
		###LogSD		"Checking if an instance needs built for key: $key" ] );
		if( $key =~ /_inst$/ and !is_Object( $args{$key} ) and is_HashRef( $args{$key} ) ){
			# Import log_space as needed
			###LogSD	if( exists $args{log_space} and $args{log_space} ){
			###LogSD		$args{$key}->{log_space} = $args{log_space};
			###LogSD	}
			###LogSD	$phone->talk( level => 'trace', message =>[
			###LogSD		"Key -$key- requires an instance built from:", $args{$key} ] );
			$args{$key} = build_instance( $args{$key} );
		}
	}
	
	# Pull any delayed build items - probably to allow them to observe the workbook instance
	for my $key ( @$delay_till_build ){
		###LogSD	$phone->talk( level => 'trace', message =>[
		###LogSD		"Delaying the installation of: $key" ] );
		my $build_delay_store = {};
		if( exists $args{$key} ){
			$build_delay_store->{$key} = $args{$key};
			delete $args{$key};
		}
		$args{_delay_till_build} = $build_delay_store;
	}
	
	###LogSD	$phone->talk( level => 'trace', message =>[
	###LogSD			"Final BUILDARGS:", %args ] );
	my $workbook = Spreadsheet::XLSX::Reader::LibXML::Workbook->new( %args );
    return $class->$orig( 
				_workbook => $workbook,
	###LogSD	log_space => $args{log_space}
	);
};

around parse => sub{
	my ( $orig, $self, @args ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space =>
	###LogSD			$self->get_all_space . '::_around::parse', );
	###LogSD		$phone->talk( level => 'info', message =>[
	###LogSD			"Adding the built workbook to the workbook attribute with args:", @args ] );
	my $workbook = $self->$orig( @args );
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD			"setting the returned workbook" ] );
	###LogSD	$phone->talk( level => 'trace', message =>[ $workbook ] );
	$self->_set_workbook( $workbook ) if $workbook;
};

sub DEMOLISH{
	my ( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new( name_space =>
	###LogSD			$self->get_all_space . '::_hidden::DEMOLISH', );
	###LogSD		$phone->talk( level => 'debug', message =>[
	###LogSD			"Forcing Non-recursive garbage collection on recursive stuff" ] );
	if( $self->_has_workbook ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Need to demolish the workbook" ] );
		$self->_demolish_the_workbook;
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Clearing the attribute" ] );
		$self->_clear_the_workbook;
	}
}

#########1 Phinish            3#########4#########5#########6#########7#########8#########9

no Moose;
__PACKAGE__->meta->make_immutable;
	
1;

#########1 Documentation      3#########4#########5#########6#########7#########8#########9
__END__

=head1 NAME

Spreadsheet::XLSX::Reader::LibXML - Read xlsx spreadsheet files with LibXML

=begin html

<a href="https://www.perl.org">
	<img src="https://img.shields.io/badge/perl-5.10+-brightgreen.svg" alt="perl version">
</a>

<a href="https://travis-ci.org/jandrew/Spreadsheet-XLSX-Reader-LibXML">
	<img alt="Build Status" src="https://travis-ci.org/jandrew/Spreadsheet-XLSX-Reader-LibXML.png?branch=master" alt='Travis Build'/>
</a>

<a href='https://coveralls.io/r/jandrew/Spreadsheet-XLSX-Reader-LibXML?branch=master'>
	<img src='https://coveralls.io/repos/jandrew/Spreadsheet-XLSX-Reader-LibXML/badge.svg?branch=master' alt='Coverage Status' />
</a>

<a href='https://github.com/jandrew/DateTimeX-Format-Excel'>
	<img src="https://img.shields.io/github/tag/jandrew/Spreadsheet-XLSX-Reader-LibXML.svg?label=github version" alt="github version"/>
</a>

<a href="https://metacpan.org/pod/Spreadsheet::XLSX::Reader::LibXML">
	<img src="https://badge.fury.io/pl/Spreadsheet-XLSX-Reader-LibXML.svg?label=cpan version" alt="CPAN version" height="20">
</a>

<a href='http://cpants.cpanauthors.org/dist/Spreadsheet-XLSX-Reader-LibXML'>
	<img src='http://cpants.cpanauthors.org/dist/Spreadsheet-XLSX-Reader-LibXML.png' alt='kwalitee' height="20"/>
</a>

=end html

=head1 SYNOPSIS

The following uses the 'TestBook.xlsx' file found in the t/test_files/ folder of the package

	#!/usr/bin/env perl
	use strict;
	use warnings;
	use Spreadsheet::XLSX::Reader::LibXML;

	my $parser   = Spreadsheet::XLSX::Reader::LibXML->new();
	my $workbook = $parser->parse( 'TestBook.xlsx' );

	if ( !defined $workbook ) {
		die $parser->error(), "\n";
	}

	for my $worksheet ( $workbook->worksheets() ) {

		my ( $row_min, $row_max ) = $worksheet->row_range();
		my ( $col_min, $col_max ) = $worksheet->col_range();

		for my $row ( $row_min .. $row_max ) {
			for my $col ( $col_min .. $col_max ) {

				my $cell = $worksheet->get_cell( $row, $col );
				next unless $cell;

				print "Row, Col    = ($row, $col)\n";
				print "Value       = ", $cell->value(),       "\n";
				print "Unformatted = ", $cell->unformatted(), "\n";
				print "\n";
			}
		}
		last;# In order not to read all sheets
	}

	###########################
	# SYNOPSIS Screen Output
	# 01: Row, Col    = (0, 0)
	# 02: Value       = Category
	# 03: Unformatted = Category
	# 04: 
	# 05: Row, Col    = (0, 1)
	# 06: Value       = Total
	# 07: Unformatted = Total
	# 08: 
	# 09: Row, Col    = (0, 2)
	# 10: Value       = Date
	# 11: Unformatted = Date
	# 12: 
	# 13: Row, Col    = (1, 0)
	# 14: Value       = Red
	# 16: Unformatted = Red
	# 17: 
	# 18: Row, Col    = (1, 1)
	# 19: Value       = 5
	# 20: Unformatted = 5
	# 21: 
	# 22: Row, Col    = (1, 2)
	# 23: Value       = 2017-2-14 #(shows as 2/14/2017 in the sheet)
	# 24: Unformatted = 41318
	# 25: 
	# More intermediate rows ... 
	# 82: 
	# 83: Row, Col    = (6, 2)
	# 84: Value       = 2016-2-6 #(shows as 2/6/2016 in the sheet)
	# 85: Unformatted = 40944
	###########################

=head1 DESCRIPTION

This is an object oriented just in time Excel spreadsheet reader package that should 
parse all excel files with the extentions .xlsx, .xlsm, .xml I<L<Excel 2003 xml
|https://en.wikipedia.org/wiki/Microsoft_Office_XML_formats> (SpreadsheetML)> that 
can be opened in Excel 2007+ applications.  The quick-start example provided in the 
SYNOPSIS attempts to follow the example from L<Spreadsheet::ParseExcel> (.xls binary 
file reader) as close as possible.  There are additional methods and other approaches 
that can be used by this package for spreadsheet reading but the basic access to data 
from newer xml based Excel files can be as simple as above.

The intent is to fully document all public functions but you may need to go to sub 
modules to find more detailed documentation.  This package operates on the Excel file 
with three primary tiers of classes.  Each level provides object methods to access the 
next level down.

=over

Workbook level (This doc)

=over

=item * General attribute settings that affect parsing of the file in general

=item * The place to L<set workbook level output formatting|Spreadsheet::XLSX::Reader::LibXML::FormatInterface>

=item * Object methods to retreive document level metadata

=item * Object methods to return specific Worksheet instances for data retrieval

=item * The place to L<set workbook level formatting|Spreadsheet::XLSX::Reader::LibXML::FormatInterface>

=over

L<Worksheet level|Spreadsheet::XLSX::Reader::LibXML::Worksheet>

=over

=item * Object methods to return specific cell instances/L<data|/group_return_type>

=item * Access to some worksheet level format information (more access pending)

=item * The place to L<customize|Spreadsheet::XLSX::Reader::LibXML::Worksheet/custom_formats> 
data output formats targeting specific cell ranges

=over

L<Cell level|Spreadsheet::XLSX::Reader::LibXML::Cell>

=over

=item * Access to the cell contents

=item * Access to the cell formats (more access pending)

=back

=back

=back

=back

=back

=back

There are some differences from the L<Spreadsheet::ParseExcel> package.  For instance 
in the L<SYNOPSIS|/SYNOPSIS> the '$parser' and the '$workbook' are actually the same 
class for this package.  You could therefore combine both steps by calling ->new with 
the 'file' attribute called out.  The test for load success would then rely on the 
method L<file_opened|/file_opened>.   Afterward it is still possible to call ->error 
on the instance.  Another difference is the data formatter and specifically date 
handling.  This package allows for a simple pluggable custom output format that is 
very flexible as well as handling dates older than 1-January-1900.  I leveraged 
coercions from L<Type::Tiny|Type::Tiny::Manual> to do this but anything that follows 
that general format will work here.  Additionally, this is a L<Moose> based package 
and possible I also use interfaces for each of the sub-roles/classes used in parsing.  
This should alow you to change only the part you want to perform differently if you 
have the desire to tinker with the guts.  Read the full documentation for all 
opportunities!

In the realm of extensibility this package uses L<XML::LibXML> which has multiple ways 
to read an XML file but this release only has an L<XML::LibXML::Reader> parser option.  
Future iterations could include a DOM parser option but that is a very low priority.  
Currently this package does not provide the same access to the visual format elements 
provided in L<Spreadsheet::ParseExcel>.  That is on the longish and incomplete TODO list.  
To skip the why and nitty gritty of design and jump to implementation details go to the 
L<Attributes|/Attributes> section.

=head2 Architecture Choices

This is yet another package for parsing Excel xml or 2007+ workbooks.  The goals of this 
package are five fold.  First, as close as possible produce the same output as is visible 
in an excel spreadsheet with exposure to underlying settings from Excel.  Second, adhere 
as close as is reasonable to the L<Spreadsheet::ParseExcel> API (where it doesn't conflict 
with the first objective) so that less work would be needed to integrate ParseExcel and 
this package.  An addendum to the second goal is this package will not expose elements of 
the object hash for use by the consuming program.  This package will either return an 
unblessed hash with the equivalent elements to the Spreadsheet::ParseExcel output (instead 
of a class instance) or it will provide methods to provide these sets of data.  The third 
goal is to provide an XLSX sheet parser that is built on L<XML::LibXML>.  The other two 
primary options for XLSX parsing on CPAN use either a one-off XML parser (L<Spreadsheet::XLSX>) 
or L<XML::Twig> (L<Spreadsheet::ParseXLSX>).  In general if either of them already work for 
you without issue then there is no reason to switch to this package.  Fourth, excel files 
get abused in the wild.  They get abused by humans and they get abused by scripts.  In 
general the Excel application handles this mangling gracefully. The goal here is to be able 
to read any xml based spreadsheet Excel can read.  Please L<submit examples
|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML/issues> where this is not true 
to my github repo so I can work to improve this package.  If you don't want your test case 
included with the distribution I will use it to improve the package without publishing it.  
Fifth (and finally), the design of this package is targeted at handling as large of an Excel 
file as possible.  In general this means that design decisions will generally sacrifice speed 
to keep RAM consumption low.  Specifically this spreadsheet parser does not read the file into 
memory completely when it is opened.  Since the data in the sheet is parsed just in time the 
information that is not contained in the primary meta-data headers will not be available for 
review L<until the sheet parses to that point|Spreadsheet::XLSX::Reader::LibXML::Worksheet/max_row>.  
In cases where the parser has made choices that prioritize speed over RAM savings there 
will generally be an L<attribute available to turn that decision off|/set_cache_behavior>.  
All in all this package solves many of the issues I found parsing Excel in the wild.  I 
hope it solves some of yours as well.

=head2 Warnings

B<1.>This package uses L<Archive::Zip>.  Not all versions of Archive::Zip work for everyone.  
I have tested this with Archive::Zip 1.30.  Please let me know if this does not work with a 
sucessfully installed (read passed the full test suit) version of Archive::Zip newer than that.

B<2.> Not all workbook sheets (tabs) are created equal!  Some Excel sheet tabs are only a 
chart.  These tabs are 'chartsheets'.  The methods with 'worksheet' in the name only act on 
the sub set of tabs that are worksheets.  Future methods with 'chartsheet' in the name will 
focus on the subset of sheets that are chartsheets.  Methods with just 'sheet' in the name 
have the potential to act on both.  The documentation for the chartsheet level class is found 
in L<Spreadsheet::XLSX::Reader::LibXML::Chartsheet> (still under construction).  All chartsheet 
classes do not provide access to cells.

B<3.> This package supports reading xlsm files (Macro enabled Excel 2007+ workbooks).  
xlsm files allow for binaries to be embedded that may contain malicious code.  However, other 
than unzipping the excel file no work is done by this package with the sub-file 'vbaProject.bin' 
containing the binaries.  This package does not provide an API to that sub-file and I have no 
intention of doing so.  Therefore my research indicates there should be no risk of virus activation 
while parsing even an infected xlsm file with this package but I encourage you to use your own 
judgement in this area. B<L<caveat utilitor!|https://en.wiktionary.org/wiki/Appendix:List_of_Latin_phrases>>

B<4.> This package will read some files with 'broken' xml.  In general this should be 
transparent but in the case of the maximum row value and the maximum column value for a 
worksheet it can cause some surprising problems.  This includes the possibility that the maximum 
values are initially stored as 'undef' if the sheet does not provide them in the metadata as 
expected.  The answer to the methods L<Spreadsheet::XLSX::Reader::LibXML::Worksheet/row_range> and 
L<Spreadsheet::XLSX::Reader::LibXML::Worksheet/col_range> will then change as more of the sheet is 
parsed.  The parser improves these values as information is available based on the dimensional 
scope of the users cell parsing.  These values are generally never available in Excel 2003 xml files.  
The primary cause of these broken XML elements in Excel 2007+ files are non-XML applications writing 
to the excel spreadsheet.  You can use the attribute L<file_boundary_flags|/file_boundary_flags> or 
the methods L<Spreadsheet::XLSX::Reader::LibXML::Worksheet/get_next_value> or 
L<Spreadsheet::XLSX::Reader::LibXML::Worksheet/fetchrow_arrayref> as alternates for pre-testing 
for boundaries when iterating.

B<5.> Version v0.40.2 changes the way file caching is turned on and off.  It also changes the 
way it is set when starting an instance of this package.  If you did not turn off caching 
explicitly before this release there should no be a problem with this change.  The goal is to 
automatically differentiate large files and small files and L<turn caching off|/cache_positions> 
in a targeted manner in response to larger file sizes. This should allow larger spreadsheets that 
may have exceeded available RAM to run (slowly) when they didn't run at all before without forcing 
small sheets to run too much slower. However, if you do have caching turned off in your code using 
the old Boolean setting this package will now see it, fix it upon load, and emit a warning.  I will 
still be tweaking this setting over the next few releases.  This warning will stay till 3/1/2017 
and then the old callout will no longer be supported.

B<6.> Version v0.40.2 introduces the L<file|/file> attribute and will start the deprication of the 
L<file_name|/file_name> and L<file_handle|/file_handle> attributes as well as the following methods: 
L<set_file_name|/set_file_name>, L<set_file_handle|/set_file_handle>, L<file_handle|/file_handle>, 
and L<has_file_handle|/has_file_handle>.  This change is intended to remove an overly complex 
set of dependancies that was causing trouble for garbage collection on cleanup.  Please use 
the L<file|/file> attribute and the L<file_opened|/file_opened> methods as replacements moving 
forward.  Support for backwards compatible use of the old attributes and methods will be removed 
after 3/1/2017.

B<7.> Version v0.40.2 introduces support for L<SpreadsheetML
|https://odieweblog.wordpress.com/2012/02/12/how-to-read-and-write-office-2003-excel-xml-files/> 
(Excel 2003) .xml extention documents.  These documents should include

	xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
	
as an attribute in the Workbook node to indicate their intended format.  This change does introduce 
a lot of behind the scenes re-plumbing but the top level tests all stayed the same.  This means that 
for .xlsx and .xlsm extentions there should not be any obvious changes or (hopefully) significant 
new bugs. I<Note warnings 5 and 6>.  However, to get this release out and rolling I don't have a 
full set of tests for the .xml extention paths and Microsofts documentation for that format is 
spotty in some relevant areas (I still don't know what I don't know) so please L<submit
|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML/issues> any cases that appear to behave 
differently than expected for .xml extention files that are readable by the Excel application.  
I am also interested in cases where an out of memory error occurs with an .xml extension file.  This 
warning will stay till 3/1/2017.

=head2 Attributes

Data passed to new when creating an instance.  For modification of these attributes see the 
listed 'attribute methods'. For general information on attributes see 
L<Moose::Manual::Attributes>.  For ways to manage the workbook when opened see the 
L<Primary Methods|/Primary Methods>.  For additional lesser used workbook options 
see L<Secondary Methods|/Secondary Methods>.

B<Example>

	$workbook_instance = Spreadsheet::XLSX::Reader::LibXML->new( %attributes )

I<note: if the file information is not included in the initial %attributes then it must be 
set by one of the attribute setter methods below or the L<parse
|parse( $file_nameE<verbar>$file_handle, $formatter )> method before the rest of the package 
can be used.>

=head3 file_name

=over

B<Definition:> This attribute holds the full file name and path for the xlsx|xlsm file to be 
parsed.

B<Default> no default - either this or a L<file handle|/file_handle> must be provided to 
read a file

B<Range> any unencrypted xlsx|xlsm file that can be opened in Microsoft Excel.

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_file_name>

=over

B<Definition:> change the file name value in the attribute (this will reboot 
the workbook instance)

=back

B<has_file_name>

=over

B<Definition:> this is used to see if the workbook loaded correctly using the 
file_name option to open an Excel .xlsx file.

=back

=back

=back

=head3 file_handle

=over

B<Definition:> This attribute holds a copy of the passed file handle reference.

B<Default> no default - either this or a L<file name|/file_name> must be provided to read 
a file

B<Range> any unencrypted xlsx file handle that can be opened in Microsoft Excel

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_file_handle>

=over

B<Definition:> change the set file handle (this will reboot the workbook instance)

=back

B<has_file_handle>

=over

B<Definition:> this is used to see if the workbook loaded correctly when using the 
file_handle option to open an Excel .xlsx file.

=back

=back

=back

=head3 error_inst

=over

B<Definition:> This attribute holds an 'error' object instance.  It should have several 
methods for managing errors.  Currently no error codes or error language translation 
options are available but this should make implementation of that easier.

B<Default:> a L<Spreadsheet::XLSX::Reader::LibXML::Error> instance with the attributes set 
as;
	
	( should_warn => 0 )

B<Range:> The minimum list of methods to implement for your own instance is;

	error set_error clear_error set_warnings if_warn
	
The error instance must be able to extract the error string from a passed error 
object as well.  For now the current implementation will attempt ->as_string first 
and then ->message if an object is passed.

B<attribute methods> Methods provided to adjust this attribute

=over

B<get_error_inst>

=over

B<Definition:> returns this instance

=back

B<error>

=over

B<Definition:> delegated method from the class used to get the most recently 
logged error string

=back

B<set_error>

=over

B<Definition:> delegated method from the class used to set a new error string 
(or pass an error object for extraction of the error string)

=back

B<clear_error>

=over

B<Definition:> delegated method from the class used to clear the current error 
string

=back

B<set_warnings>

=over

B<Definition:> delegated method from the class used to turn on or off real time 
warnings when errors are set

=back

B<if_warn>

=over

B<Definition:> delegated method from the class used to extend this package and 
see if warnings should be emitted.

=back

B<should_spew_longmess>

=over

B<Definition:> delegated method from the class used to turn on or off the L<Carp> 
'longmess'for error messages

=back

B<spewing_longmess>

=over

B<Definition:> delegated method from the class used to understand the current state 
the longmess concatenation for error messages

=back
		
=back

=back

=head3 sheet_parser

=over

B<Definition:> This sets the way the .xlsx file is parsed.  For now the only 
choice is 'reader'.

B<Default> 'reader'

B<Range> 'reader'

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_parser_type>

=over

B<Definition:> the way to change the parser type

=back

B<get_parser_type>

=over

B<Definition:> returns the currently set parser type

=back

=back

=back

=head3 count_from_zero

=over

B<Definition:> Excel spreadsheets count from 1.  L<Spreadsheet::ParseExcel> 
counts from zero.  This allows you to choose either way.

B<Default> 1

B<Range> 1 = counting from zero like Spreadsheet::ParseExcel, 
0 = Counting from 1 like Excel

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<counting_from_zero>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_count_from_zero>

=over

B<Definition:> a way to change the current attribute setting

=back

=back

=back

=head3 file_boundary_flags

=over

B<Definition:> When you request data to the right of the last column or below 
the last row of the data this package can return 'EOR' or 'EOF' to indicate that 
state.  This is especially helpful in 'while' loops.  The other option is to 
return 'undef'.  This is problematic if some cells in your table are empty which 
also returns undef.  What is determined to be the last column and row is determined 
by the attribute L<empty_is_end|/empty_is_end>.

B<Default> 1

B<Range> 1 = return 'EOR' or 'EOF' flags as appropriate, 0 = return undef when 
requesting a position that is out of bounds

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<boundary_flag_setting>

=over

B<Definition:> a way to check the current attribute setting

=back

B<change_boundary_flag>

=over

B<Definition:> a way to change the current attribute setting

=back

=back

=back

=head3 empty_is_end

=over

B<Definition:> The excel convention is to read the table left to right and top 
to bottom.  Some tables have an uneven number of columns with real data from row 
to row.  This allows the several methods that excersize a 'next' function to wrap 
after the last element with data rather than going to the max column.  This also 
triggers 'EOR' flags after the last data element and before the sheet max column 
when not implementing 'next' functionality.

B<Default> 0

B<Range> 0 = treat all columns short of the max column for the sheet as being in 
the table, 1 = treat all cells after the last cell with data as past the end of 
the row.  This will be most visible when 
L<boundary flags are turned on|/boundary_flag_setting> or next functionality is 
used in the context of the L<values_only|/values_only> attribute is on.

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<is_empty_the_end>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_empty_is_end>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 values_only

=over

B<Definition:> Excel will store information about a cell even if it only contains 
formatting data.  In many cases you only want to see cells that actually have 
values.  This attribute will change the package behaviour regarding cells that have 
formatting stored against that cell but no actual value.

B<Default> 0 

B<Range> 1 = skip cells with formatting only and treat them as completely empty, 
0 = return informat about cells that only contain formatting

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_values_only>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_values_only>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 from_the_edge

=over

B<Definition:> Some data tables start in the top left corner.  Others do not.  I 
don't reccomend that practice but when aquiring data in the wild it is often good 
to adapt.  This attribute sets whether the file reads from the top left edge or from 
the top row with data and starting from the leftmost column with data.

B<Default> 1

B<Range> 1 = treat the top left corner of the sheet as the beginning of rows and 
columns even if there is no data in the top row or leftmost column, 0 = Set the 
minimum row and minimum columns to be the first row and first column with data

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_from_the_edge>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 cache_positions

=over

B<Definition:> This parse can be slow.  It does this by trading processing and 
file storage for RAM usage but that is probably not the average users choice.  
Currently four of the files can implement selective caching.  The setting for 
this attribute takes a hash ref with the file indicators as keys and the max 
file size in bytes as the value.  When the sub file handle exceeds that size 
then caching for that subfile is turned off.  The default setting shows an 
example with the four available cached size.
	
B<warning:> This behaviour changed with v0.40.2.  Prior to that this setting 
accepted a boolean value that turned all caching on or off universally.  If 
a boolean value is passed a deprication warning will be issued and the input 
will be changed to this format.  'On' will be converted to the default caching 
levels.  A boolean 'Off' is passed then the package will set all maximum caching 
levels to 0.

B<Default>

	{
		sharedStrings => 5242880,# 5 MB
		styles => 5242880,# 5 MB
		worksheet_interface => 5242880,# 5 MB
		chartsheet_interface => 5242880,# 5 MB
	}

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_cache_positions>

=over

B<Definition:> read the attribute

=back

B<get_cache_size( $target_file )>

=over

B<Definition:> return the max file size allowed to cache for the indicated $target_file

=back

B<set_cache_size( $target_file => $max_file_size )>

=over

B<Definition:> set the $max_file_size to be cached for the indicated $target_file

=back

B<has_cache_size( $target_file )>

=over

B<Definition:> returns true if one of the four allowed files is passed at $target_file

=back

=back

=back

=head3 formatter_inst

=over

B<Definition:> This is the attribute containing the formatter class.  In general the 
default value is sufficient.  However, If you want to tweak this a bit then review the
L<class documentation|Spreadsheet::XLSX::Reader::LibXML::FormatInterface>.  It does include 
a role that interprets the excel L<format string
|https://support.office.com/en-us/article/Create-or-delete-a-custom-number-format-2d450d95-2630-43b8-bf06-ccee7cbe6864?ui=en-US&rs=en-US&ad=US> 
into a L<Type::Tiny> coercion.

B<Default> An instance build from MooseX::ShortCut::BuildInstance with the following 
arguments
	{
		superclasses => ['Spreadsheet::XLSX::Reader::LibXML::FmtDefault'],
		add_roles_in_sequence =>[qw(
			Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings
			Spreadsheet::XLSX::Reader::LibXML::FormatInterface
		)],
		package => 'FormatInstance',
	}

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_formatter_inst( $instance )>

=over

B<Definition:> a way to set the current attribute instance

=back

B<get_formatter_inst>

=over

B<Definition:> a way to get the current attribute setting

=back

=back

B<delegated methods:>

	delegated_to => link_delegated_from

=over

get_formatter_region => L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/get_excel_region>

get_target_encoding => L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/get_target_encoding>

set_target_encoding => L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/set_target_encoding( $encoding )>

has_target_encoding => L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/has_target_encoding>

change_output_encoding => L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/change_output_encoding( $string )>

set_defined_excel_formats => L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/set_defined_excel_formats( %args )>

get_defined_conversion => L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/get_defined_conversion( $position )>

parse_excel_format_string => L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/parse_excel_format_string( $string, $name )>

set_date_behavior => L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/set_date_behavior( $Bool )>

set_european_first => L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/set_european_first( $Bool )>

set_formatter_cache_behavior => L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/set_cache_behavior( $Bool )>

=back

=back

=head3 group_return_type

=over

B<Definition:> Traditionally ParseExcel returns a cell object with lots of methods 
to reveal information about the cell.  In reality the extra information is not used very 
much (witness the popularity of L<Spreadsheet::XLSX>).  Because many users don't need or 
want the extra cell formatting information it is possible to get either the raw xml value, 
the raw visible cell value (seen in the Excel format bar), or the formatted cell value 
returned either the way the Excel file specified or the way you specify instead of a Cell 
instance with all the data. .  See 
L<Spreadsheet::XLSX::Reader::LibXML::Worksheet/custom_formats> to insert custom targeted 
formats for use with the parser.  All empty cells return undef no matter what.

B<Default> instance

B<Range> instance = returns a populated L<Spreadsheet::XLSX::Reader::LibXML::Cell> instance,
unformatted = returns just the raw visible value of the cell shown in the Excel formula bar, 
value = returns just the formatted value stored in the excel cell, xml_value = the raw value 
for the cell as stored in the sub-xml files

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_group_return_type>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_group_return_type>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 empty_return_type

=over

B<Definition:> Traditionally L<Spreadsheet::ParseExcel> returns an empty string for cells 
with unique formatting but no stored value.  It may be that the more accurate way of returning 
undef works better for you.  This will turn that behaviour on.  I<If Excel stores an empty 
string having this attribute set to 'undef_string' will still return the empty string!>

B<Default> empty_string

B<Range>
	empty_string = populates the unformatted value with '' even if it is set to undef
	undef_string = if excel stores undef for an unformatted value it will return undef

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_empty_return_type>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_empty_return_type>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head2 Primary Methods

These are the primary ways to use this class.  They can be used to open an .xlsx workbook.  
They are also ways to investigate information at the workbook level.  For information on 
how to retrieve data from the worksheets see the 
L<Worksheet|Spreadsheet::XLSX::Reader::LibXML::Worksheet> and 
L<Cell|Spreadsheet::XLSX::Reader::LibXML::Cell> documentation.  For additional workbook 
options see the L<Secondary Methods|/Secondary Methods> 
and the L<Attributes|/Attributes> sections.  The attributes section specifically contains 
all the methods used to adjust the attributes of this class.

All methods are object methods and should be implemented on the object instance.

B<Example:>

	my @worksheet_array = $workbook_instance->worksheets;

=head3 parse( $file_name|$file_handle, $formatter )

=over

B<Definition:> This is a convenience method to match L<Spreadsheet::ParseExcel/parse($filename, $formatter)>.  
It only works if the L<file_name|/file_name> or L<file_handle|/file_handle> attribute was not 
set with ->new.  It is one way to set the 'file_name' or 'file_handle' attribute [and the 
L<default_format_list|/default_format_list> attribute].  I<You cannot pass both a file name 
and a file handle simultaneously to this method.>

B<Accepts:>

	$file = a valid xlsx file [or a valid xlsx file handle] (required)
	[$formatter] = see the default_format_list attribute for valid options (optional)

B<Returns:> itself when passing with the xlsx file loaded to the workbook level or 
undef for failure.

=back

=head3 worksheets

=over

B<Definition:> This method will return an array (I<not an array reference>) 
containing a list of references to all worksheets in the workbook.  This is not 
a reccomended method.  It is provided for compatibility to Spreadsheet::ParseExcel.  
For alternatives see the L<get_worksheet_names|/get_worksheet_names> method and the
L<worksheet|/worksheet( $name )> methods.  B<For now it also only returns the tabular 
worksheets in the workbook.  All chart worksheets are ignored! (future inclusion will 
included a backwards compatibility policy)>

B<Accepts:> nothing

B<Returns:> an array ref of  L<Worksheet|Spreadsheet::XLSX::Reader::LibXML::Worksheet> 
objects for all worksheets in the workbook.

=back

=head3 worksheet( $name )

=over

B<Definition:> This method will return an  object to read values in the worksheet.  
If no value is passed to $name then the 'next' worksheet in physical order is 
returned. I<'next' will NOT wrap>  It also only iterates through the 'worksheets' 
in the workbook (but not the 'chartsheets').

B<Accepts:> the $name string representing the name of the worksheet object you 
want to open.  This name is the word visible on the tab when opening the spreadsheet 
in Excel. (not the underlying zip member file name - which can be different.  It will 
not accept chart tab names.)

B<Returns:> a L<Worksheet|Spreadsheet::XLSX::Reader::LibXML::Worksheet> object with the 
ability to read the worksheet of that name.  It returns undef and sets the error attribute 
if a 'chartsheet' is requested.  Or in 'next' mode it returns undef if past the last sheet.

B<Example:> using the implied 'next' worksheet;

	while( my $worksheet = $workbook->worksheet ){
		print "Reading: " . $worksheet->name . "\n";
		# get the data needed from this worksheet
	}

=back

=head3 in_the_list

=over

B<Definition:> This is a predicate method that indicates if the 'next' 
L<worksheet|/worksheet( $name )> function has been implemented at least once.

B<Accepts:>nothing

B<Returns:> true = 1, false = 0
once

=back

=head3 start_at_the_beginning

=over

B<Definition:> This restarts the 'next' worksheet at the first worksheet.  This 
method is only useful in the context of the L<worksheet|/worksheet( $name )> 
function.

B<Accepts:> nothing

B<Returns:> nothing

=back

=head3 worksheet_count

=over

B<Definition:> This method returns the count of worksheets (excluding charts) in 
the workbook.

B<Accepts:>nothing

B<Returns:> an integer

=back

=head3 get_worksheet_names

=over

B<Definition:> This method returns an array ref of all the worksheet names in the 
workbook.  (It excludes chartsheets.)

B<Accepts:> nothing

B<Returns:> an array ref

B<Example:> Another way to parse a workbook without building all the sheets at 
once is;

	for $sheet_name ( @{$workbook->worksheet_names} ){
		my $worksheet = $workbook->worksheet( $sheet_name );
		# Read the worksheet here
	}

=back

=head3 get_sheet_names

=over

B<Definition:> This method returns an array ref of all the sheet names (tabs) in the 
workbook.  (It includes chartsheets.)

B<Accepts:> nothing

B<Returns:> an array ref

=back

=head3 get_chartheet_names

=over

B<Definition:> This method returns an array ref of all the chartsheet names in the 
workbook.  (It excludes worksheets.)

B<Accepts:> nothing

B<Returns:> an array ref

=back

=head3 sheet_name( $Int )

=over

B<Definition:> This method returns the sheet name for a given physical position 
in the workbook from left to right. It counts from zero even if the workbook is in 
'count_from_one' mode.  B(It will return chart names but chart tab names cannot currently 
be converted to worksheets). You may actually want L<worksheet_name|worksheet_name( $Int )> 
instead of this function.

B<Accepts:> integers

B<Returns:> the sheet name (both workbook and worksheet)

B<Example:> To return only worksheet positions 2 through 4

	for $x (2..4){
		my $worksheet = $workbook->worksheet( $workbook->worksheet_name( $x ) );
		# Read the worksheet here
	}

=back

=head3 sheet_count

=over

B<Definition:> This method returns the count of all sheets in the workbook (worksheets 
and chartsheets).

B<Accepts:> nothing

B<Returns:> a count of all sheets

=back

=head3 worksheet_name( $Int )

=over

B<Definition:> This method returns the worksheet name for a given order in the workbook 
from left to right. It does not count any 'chartsheet' positions as valid.  It counts 
from zero even if the workbook is in 'count_from_one' mode.

B<Accepts:> integers

B<Returns:> the worksheet name

B<Example:> To return only worksheet positions 2 through 4 and then parse them

	for $x (2..4){
		my $worksheet = $workbook->worksheet( $workbook->worksheet_name( $x ) );
		# Read the worksheet here
	}

=back

=head3 worksheet_count

=over

B<Definition:> This method returns the count of all worksheets in the workbook (not 
including chartsheets).

B<Accepts:> nothing

B<Returns:> a count of all worksheets

=back

=head3 chartsheet_name( $Int )

=over

B<Definition:> This method returns the chartsheet name for a given order in the workbook 
from left to right. It does not count any 'worksheet' positions as valid.  It counts 
from zero even if the workbook is in 'count_from_one' mode.

B<Accepts:> integers

B<Returns:> the chartsheet name

=back

=head3 chartsheet_count

=over

B<Definition:> This method returns the count of all chartsheets in the workbook (not 
including worksheets).

B<Accepts:> nothing

B<Returns:> a count of all chartsheets

=back

=head3 error

=over

B<Definition:> This returns the most recent error message logged by the package.  This 
method is mostly relevant when an unexpected result is returned by some other method.

B<Accepts:>nothing

B<Returns:> an error string.

=back

=head2 Secondary Methods

These are the additional methods that include ways to extract additional information about 
the .xlsx file and ways to modify workbook and worksheet parsing that are less common.  
Note that all methods specifically used to adjust workbook level attributes are listed in 
the L<Attribute|/Attribute> section.  This section primarily contains methods for or 
L<delegated|Moose::Manual::Delegation> from private attributes set up during the workbook 
load process.

=head3 parse_excel_format_string( $format_string )

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/parse_excel_format_string( $string )>

=back

=head3 creator

=over

B<Definition:> Retrieve the stored creator string from the Excel file.

B<Accepts> nothing

B<Returns> A string

=back

=head3 date_created

=over

B<Definition:> returns the date the file was created

B<Accepts> nothing

B<Returns> A string

=back

=head3 modified_by

=over

B<Definition:> returns the user name of the person who last modified the file

B<Accepts> nothing

B<Returns> A string

=back

=head3 date_modified

=over

B<Definition:> returns the date when the file was last modified

B<Accepts> nothing

B<Returns> A string

=back

=head3 get_epoch_year

=over

B<Definition:> This returns the epoch year defined by the Excel workbook.

B<Accepts:> nothing

B<Returns:> 1900 = Windows Excel or 1904 = Apple Excel

=back

=head3 get_shared_string

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::SharedStrings/get_shared_string( $position )>

=back

=head3 get_format_position

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::Styles/get_format_position( $position, [$header] )>

=back

=head3 set_defined_excel_format_list

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/set_defined_excel_format_list>

=back

=head3 change_output_encoding

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault/change_output_encoding( $string )>

=back

=head3 set_cache_behavior

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/cache_formats>

=back

=head3 get_date_behavior

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/datetime_dates>

=back

=head3 set_date_behavior

=over

Roundabout delegation from 
L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings/datetime_dates>

=back

=head1 FLAGS

The parameter list (attributes) that are possible to pass to ->new is somewhat long.  
Therefore you may want a shortcut that aggregates some set of attribute settings that 
are not the defaults but wind up being boilerplate.  I have provided possible 
alternate sets like this and am open to providing others that are suggested.  The 
flags will have a : in front of the identifier and will be passed to the class in the 
'use' statement for consumption by the import method.  The flags can be stacked and 
where there is conflict between the flag settings the rightmost passed flag setting is 
used.

Example;

	use Spreadsheet::XLSX::Reader::LibXML v0.34.4 qw( :alt_default :debug );

=head2 :alt_default

This is intended for a deep look at data and skip formatting cells.

=over

B<Default attribute differences>

=over

L<values_only|/values_only> => 1

L<count_from_zero|/count_from_zero> => 0

L<empty_is_end|/empty_is_end> => 1

=back

=back

=head2 :just_the_data

This is intended for a shallow look at data and skip formatting.

=over

B<Default attribute differences>

=over

L<values_only|/values_only> => 1

L<count_from_zero|/count_from_zero> => 0

L<empty_is_end|/empty_is_end> => 1

L<group_return_type|/group_return_type> => 'value'

L<cache_positions|/cache_positions> => 1

L<from_the_edge|/from_the_edge> => 0,

=back

=back

=head2 :just_raw_data

This is intended for a shallow look at raw text and skips all formatting including number formats.

=over

B<Default attribute differences>

=over

L<values_only|/values_only> => 1

L<count_from_zero|/count_from_zero> => 0

L<empty_is_end|/empty_is_end> => 1

L<group_return_type|/group_return_type> => 'unformatted'

L<cache_positions|/cache_positions> => 1

L<from_the_edge|/from_the_edge> => 0,

=back

=back

=head2 :debug

Turn on L<Spreadsheet::XLSX::Reader::LibXML::Error/should_warn> in the Error attribute (instance)

=over

B<Default attribute differences>

=over

L<Spreadsheet::XLSX::Reader::LibXML::Error/should_warn> => 1

=back

=back

=head1 BUILD / INSTALL from Source

B<0.> Please note that using L<cpanm|https://metacpan.org/pod/App::cpanminus> is much easier 
than a source build! (but it will not always give the latest github version)

	cpanm Spreadsheet::XLSX::Reader::LibXML
	
And then if you feel kindly

	cpanm-reporter

B<1.> This package uses L<Alien::LibXML> to try and ensure that the mandatory prerequisite #######################################################################################  Check this
L<XML::LibXML> will load.  The biggest gotcha here is that older (<5.20.0.2) versions of 
Strawberry Perl and some other Win32 perls may not support the script 'pkg-config' which is 
required.  You can resolve this by installation L<PkgConfig> as 'pkg-config'.  I have 
included the short version of that process below but download the full L<PkgConfig> distribution 
and read README.win32 file for other options and much more explanation.

=over

B<this will conflict with any existing pkg-config installed>

	C:\> cpanm PkgConfig --configure-args=--script=pkg-config
	
=back

It may be that you still need to use a system package manager to L<load|http://xmlsoft.org/> the 
'libxml2-devel' library.  If this is the case or you experience any other installation issues please 
L<submit them to github|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML/issues> especially 
if they occur prior to starting the test suit as these failures will not auto push from CPAN Testers 
so I won't know to fix them!
	
B<2.> Download a compressed file with this package code from your favorite source

=over

L<github|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML>

L<Meta::CPAN|https://metacpan.org/pod/Spreadsheet::XLSX::Reader::LibXML>

L<CPAN|http://search.cpan.org/~jandrew/Spreadsheet-XLSX-Reader-LibXML/>

=back
	
B<3.> Extract the code from the compressed file.

=over

If you are using tar on a .tar.gz file this should work:

	tar -zxvf Spreadsheet-XLSX-Reader-LibXML-v0.xx.tar.gz
	
=back

B<4.> Change (cd) into the extracted directory

B<5.> Run the following

=over

(for Windows find what version of make was used to compile your perl)

	perl  -V:make
	
(then for Windows substitute the correct make function (s/make/dmake/g)? below)
	
=back

	perl Makefile.PL

	make

	make test

	make install # As sudo/root

	make clean

=head1 SUPPORT

=over

L<github Spreadsheet::XLSX::Reader::LibXML/issues|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML/issues>

=back

=head1 TODO

=over

B<1.> Add POD for all the new chart methods!

B<1.> Build an 'Alien::LibXML::Devel' package to load the libxml2-devel libraries from source and 
require that and L<Alien::LibXML> in the build file. So all needed requirements for L<XML::LibXML> 
are met

=over

Both libxml2 and libxml2-devel libraries are required for XML::LibXML

=back

B<1.> Add an individual test just for Spreadsheet::XLSX::Reader::LibXML::Row (Currently tested in the worksheet test)

B<2.> Add an individual test just for Spreadsheet::XLSX::Reader::LibXML::ZipReader (Currently only tested in the top level test)

B<3.> Add individual tests just for the File, Meta, Props, Rels sub workbook interfaces

B<4.> Add an individual test just for Spreadsheet::XLSX::Reader::LibXML::ZipReader::ExtractFile

B<5.> Add individual tests just for the XMLReader sub modules NamedStyles, and PositionStyles

B<6.> Add a pivot table reader (Not just read the values from the sheet)

B<7.> Add calc chain methods

B<8.> Add more exposure to workbook/worksheet formatting values

B<9.> Build a DOM parser alternative for the sheets

=over

(Theoretically faster than the reader and no longer JIT so it uses more memory)

=back

=back

=head1 AUTHOR

=over

Jed Lund

jandrew@cpan.org

=back

=head1 CONTRIBUTORS

This is the (likely incomplete) list of people who have helped
make this distribution what it is, either via code contributions, 
patches, bug reports, help with troubleshooting, etc. A huge
'thank you' to all of them.

=over

L<Frank Maas|https://github.com/Frank071>

L<Stuart Watt|https://github.com/morungos>

L<Toby Inkster|https://github.com/tobyink>

L<Breno G. de Oliveira|https://github.com/garu>

L<Bill Baker|https://github.com/wdbaker54>

L<H.Merijin Brand|https://github.com/Tux>

L<Todd Eigenschink|mailto:todd@xymmetrix.com>

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

This software is copyrighted (c) 2014, 2016 by Jed Lund

=head1 DEPENDENCIES

=over

L<perl 5.010|perl/5.10.0>

L<Archive::Zip>

L<Carp>

L<Clone>

L<DateTime::Format::Flexible>

L<DateTimeX::Format::Excel>

L<IO::File>

L<List::Util> - 1.33

L<Moose> - 2.1213

L<MooseX::HasDefaults::RO>

L<MooseX::ShortCut::BuildInstance> - 1.032

L<MooseX::StrictConstructor>

L<Type::Tiny> - 1.000

L<XML::LibXML>

L<version> - 0.077

=back

=head1 SEE ALSO

=over

L<Spreadsheet::Read> - generic Spreadsheet reader that (hopefully) supports this package

L<Spreadsheet::ParseExcel> - Excel version 2003 and earlier

L<Spreadsheet::XLSX> - Excel version 2007 and later

L<Spreadsheet::ParseXLSX> - Excel version 2007 and later

L<Log::Shiras|https://github.com/jandrew/Log-Shiras>

=over

All lines in this package that use Log::Shiras are commented out

=back

=back

=begin html

<a href="http://www.perlmonks.org/?node_id=706986">
	<img src="http://www.perlmonksflair.com/jandrew.jpg" alt="perl monks">
</a>

=end html

=cut

#########1#########2 main pod documentation end  5#########6#########7#########8#########9
