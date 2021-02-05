# Juki570
A couple of bits of Perl that will parse an Eagle .BRD file and produce a Juki .P5A file for the 570 series SMD

The Juki .P5A format is a binary format used in the 570L and KP620E series of pick and place machines

This set of scripts will directly parse an Eagle .BRD file and produce a .P5A file to run directly on the machine. A simple MySQL database stores component values and patterns. The "mountable" field determines if the component will be written to the production file or left as hand insertion.

Known Issues: on V1.7 software, the machine may carp about "bad parameter" during the upload. This is related to 3 checksums in the data that I have not been able to discover the method used to generate the checksum.  The file actually loads fine and if re-saved back to the disc, the correct checksums are inserted by the machine and you'll not see the warning again.
