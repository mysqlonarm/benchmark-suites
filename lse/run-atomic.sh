for op in EXCHANGE LOAD STORE FENCE BAD_CAS OK_CAS FETCH_OR FETCH_ADD;
do
  echo $op
  #for march in "" "-march=armv8-a" "-march=armv8-a+lse" "-march=native";
  for march in ""
  do
    printf "%10s " $march
    printf "\n"
    g++ -o atomic -O2 -std=c++14 -D$op $march atomic.cc -lpthread
    for (( c=1; c<=256; c*=2 ))
    do
       printf "%20s " $c
       (time ./atomic $c)2>&1 | xargs -l3 echo
    done
  done
done
