#!/usr/bin/perl 

use warnings;
use strict;

use Data::Dumper;


package ReportWriter;

sub new{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
 
    return $self;
}


sub setBoard{
  my($self,$board)=@_;
  
  $self->{_board}=$board;
}


sub writeReport{

my ($self,$outfile)=@_;

    open(my$FT,">$outfile.txt") or die "Can't open $outfile.txt file for writing: $!\n";
    
    print $FT "Setup Data for ".$self->{_board}->getFileName().", produced at ".scalar(gmtime)."\n\n\n";
    
    print $FT "Feeders: ".scalar(@{$self->{_board}->getFeederList()})."\n";
    print $FT "Placements: ".scalar(@{$self->{_board}->getMountable()})."\n";
    print $FT "Hand Insertions: ".scalar(@{$self->{_board}->getHandInsertions()})."\n";
    
    my($count)=0;
    if(scalar(@{$self->{_board}->getFids()}) > 0){
    
      print $FT "\nFiducials: \n";
      foreach my $fid (@{$self->{_board}->getFids()}){
      $count++;
        print $FT "$count: X ".$fid->{x}.", Y ".$fid->{y}."\n";
      }
    }else{
      print $FT "\nNo Fiducials Found\n";
    }
    
    $count=0;
    print $FT "\n\nFeeder List:\n\n";
    foreach my $feeder(@{$self->{_board}->getFeederList()}){
      $count++;
      print $FT "$count : ".$feeder->{name}." ".$feeder->{pattern}." (".$feeder->{count}.")\n";
    }
    
    $count=0;
    print $FT "\n\nSMD List:\n\n";
    foreach my $c (@{$self->{_board}->getMountable()}){
      $count++;
      print $FT "$count : ".$c->{name}." ".$c->{value}."\n";
    }
    
    
    $count=0;
    print $FT "\n\nHand Insertions:\n\n";
    foreach my $c (@{$self->{_board}->getHandInsertions()}){
      $count++;
      print $FT "$count : ".$c->{name}." ".$c->{value}."\n";
    }
    
    close $FT;

}

1;