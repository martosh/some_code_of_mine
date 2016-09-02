#!/bin/bash

#Simple bash script for Zip files and send files to DMP
#to execute this sciript use ./script.sh

path="/proj/inbox/dataprov/ar-ssn/data/SSNFS/$1";
zipdir="$path/zips/"

if [ -d $path ] 
then echo -e "\n\tUsing path dir $path\n"
else 
echo -e "\tUsage $0 <dir> Where dir contains pdf and txt files"
echo -e "\tThe $path does not exists"; exit 0;
fi

cd $path

#Report nums of txt and pdfs
txtnum=`ls | grep txt | cat -n | tail -n 1 | cut -f 1`
pdfnum=`ls | grep pdf | cat -n | tail -n 1 | cut -f 1`

echo -e "\n Txt files are:\n$txtnum\n Pdf files are:\n $pdfnum \n" ;

# create files 'xaa' with list of files.Ex: xaa file will have content '*0002*'
ls -1 *.pdf |sed 's/-.*//' |sed 's/.*/*&*/' | split -l 1;

#cicle all the x?? files and create zips
echo 'Creating zip files' 
for i in $(ls -1 x??); do zip -j SSNFS_$i.zip $(cat $i | xargs ); done;

echo -e "\nCreate zip dir $zipdir\n"
mkdir zips;

echo -e "\nMoving zip files to $zipdir\n"
mv *.zip zips/;

echo -e "\nRemove tmp files\n"
rm -- x*;

cd $zipdir

##and upload the zips to DMP:
echo -e "\nSending zip files to dmp\n"
ncftp -u ar-ssn -p ar-ssn ftp.dmp.securities.com <<END_SCRIPT
mput *.zip
END_SCRIPT

# one liner 
# result=($(ps -aux | grep NEW | grep -v color |  cut -d ' ' -f 4 )); for i in ${result[@]}; do echo $i;  done ;
