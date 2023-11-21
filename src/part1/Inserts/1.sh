#!/bin/bash

filename=tmp

function GetString {
string=$(cat $filename | head -n $1 | tail -n 1)
echo $string | awk '{print $1", " $2", " $3", " $4", " $5", " $6}'
}

function PrintBuffer {
echo "INSERT INTO Checks(Transaction_Id, SKU_Id, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)"
echo "       VALUES("
}

f_count=$(echo $(wc -l $filename) | awk '{print $1}')

for ((i = 1; i <= $f_count; ++i)) 
do
  echo -e "$(PrintBuffer) $(GetString $i) );\n"
done
