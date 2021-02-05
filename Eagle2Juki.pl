#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use XML::Hash;
use DBI;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use EagleBoard;
use ReportWriter;
use JukiWriter17;

my($fileName) = shift @ARGV;

if(! $fileName =~ /\w+.BRD$/i){
  die "Use:  reader2.pl <eagle .BRD file>\n";
}

my($title) =  $fileName =~ /(\w+).BRD$/i;

my($outfile) = substr($title,0,8);

# print Dumper($elements);

my($board) = new EagleBoard();

$board->setFileName($fileName);
$board->process();

my($report)=new ReportWriter();
$report->setBoard($board);
$report->writeReport($outfile);

my($writer) = new JukiWriter();

$writer->setBoardName($title);
$writer->setFeeders($board->getFeederList());
$writer->setFeederIndex($board->getFeederIndex());
$writer->setPlacements($board->getMountable());

$writer->writeToFile("E:\\\\".$outfile . ".P5A");

print "Written to $outfile.P5A\n";

exit 0;


