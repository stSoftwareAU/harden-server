function cp(s,c)
{
printf "\033[%sm%s\033[0m", c, s
}

function p1(s){
split( s, a, " ")
split( a[4], t, ":")
cp(t[2]":"t[3]":"t[4], "2;37")
printf " "
cp( a[1], "33")
printf " "
  if( a[3]=="public")
  {
    cp( a[3], "34")
  }
  else
  {
    cp( a[3], "1;34");
  }
}

function p2( s)
{
split( s, a, " ")
cp( "\"" a[1] " " a[2] "\"","2;32")
}

function p3( s)
{
split( s, a, " ")
if( a[1] == "200" || a[1] == "201" || a[1] == "204" || a[1] == "205" || a[1] == "206" || a[1] == "207" )
{
  printf "%s", a[1]
}
else if ( a[1] =="302" || a[1]=="301" || a[1]=="304" )
{
  cp(a[1], "1;32")
}
else if ( a[1] =="403" )
{
  cp(a[1], "1;33")
}
else
{
  cp(a[1], "1;31")
}
printf " "
if( a[2] == "-" )
{
  cp("-", "32")
}
else
{
  b=sprintf("%'d", a[2])
  cp(b, "32")
}
}

function p5( s)
{
	split( s, a, " ")
	if( strtonum( a[1]) > 1)
	{
		if( strtonum( a[1]) > 10)
		{
			cp(a[1], "1;5;41;93")
		}
                else
		{
			cp(a[1], "1;36")
                }
	}
	else
	{
		cp(a[1], "36")
	}
	printf " "
	cp(a[2],"37")
}

{
	if( match( $0, "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+.*"))
	{
		p1($1)
		printf " "
		p2($2)
		printf " "
		p3($3)
		printf " "
		cp("\"" $4 "\"", "35")
		printf " "
		p5($7)
		print ""
	}
}

