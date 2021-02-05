#!/usr/bin/perl 

use Tk;
use Tk::TableMatrix;

package ComponentTable;



sub new{
    my $class = shift;
    my $self = {};
    bless $self, $class;
 
    return $self;
}

sub getTable{

  my($self)=shift;
  
  my($feederList)=shift;
  
  my($arrayVar)={};
  
    print "Filling Array...\n";
    my ($rows,$cols) = (scalar(@{$feederList}),5);
     foreach my $row  (0..($rows-1)){
     my($feeder) = @{$feederList}[$row];
        $arrayVar->{"$row,0"} = $row;
        $arrayVar->{"$row,1"} = $feeder->{name};
        $arrayVar->{"$row,2"} = $feeder->{pattern};
        $arrayVar->{"$row,3"} = $feeder->{count};
        $arrayVar->{"$row,4"} = join(",",@{$feeder->{usedBy}});;
    }

    print "Creating Table...\n";
    
    ## Test out the use of a callback to define tags on rows and columns
    sub colSub{
      my $col = shift;
      return "OddCol" if( $col > 0 && $col%2) ;
    }
    
     my $t = $mw->Scrolled('TableMatrix', -rows => $rows, -cols => $cols,
     -width => 6, -height => 6,
     -titlerows => 1, -titlecols => 1,
     -variable => $self->{_data},
     -coltagcommand => \&colSub,
     -colstretchmode => 'last',
     -rowstretchmode => 'last',
     -selectmode => 'extended',
     -selecttitles => 0,
     -drawmode => 'slow',
     -scrollbars=>'se'
     );
     
     $t->colWidth(0, 3);
     $t->colWidth(1, 20);
     $t->colWidth(2, 20);
     $t->colWidth(3, 3);
    
    $mw->Button(-text => "Update", -command => \&update_table)
                   ->pack(-side => 'bottom',-anchor => 'w');
    
    # Color definitions here:
    $t->tagConfigure('active', -bg => 'white', -relief => 'sunken');
    $t->tagConfigure('OddCol', -bg => 'lightyellow', -fg => 'black');
    $t->tagConfigure('title', -bg => 'lightblue', -fg => 'black', -relief => 'sunken');
    $t->tagConfigure('dis', -state => 'disabled');
    $t->pack(-expand => 1, -fill => 'both');
    $t->focus;
    
    $t->tagCol('dis',0);
    $t->tagCol('dis',1);
    $t->tagCol('dis',2);
    $t->tagCol('dis',3);
    $t->tagCol('dis',4);
    
    return $t;
}

1;