perl python2perl_v3.pl $1 | perl > perl_output_tmp
python $1 > python_output_tmp
diff perl_output_tmp python_output_tmp
rm perl_output_tmp
rm python_output_tmp