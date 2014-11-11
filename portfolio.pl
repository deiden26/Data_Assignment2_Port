#!/usr/bin/perl -w

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Use Statements
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#
# The combination of -w and use strict enforces various 
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;
# use warnings;

use Data::Dumper;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.  
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;


#
# database input and output is paired into the two arrays noted
#
my @sqlinput=();
my @sqloutput=();

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;
use Time::Local;
use POSIX qw(strftime);

#
# Tests if a scalar is a number
#
use Scalar::Util qw(looks_like_number);

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Global Variables
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#
# You need to override these for access to your database
#
my $dbuser="dbe261";
my $dbpasswd="guest";


#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again. 
#
# "RWBSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="PortSession";

#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);

#
# Will be filled in as we process the cookies and paramters
#
my @outputcookies;
my $outputcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $portName = undef;
my $stockName = undef;
my $password = undef;
my $menuOptions = undef;
my $pageContent = undef;
my $timestamp = undef;
my $startTimestamp = undef;
my $endTimestamp = undef;
my @history = undef;

my $startDate = '11/01/2005';
my $endDate = '11/10/2005';

#
# Used for displaying form completion errors
#
my $formError= undef;
my $showError = 'none';

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;
my $debug = 0;


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Debugging Mode Switch
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#
# Check for debugging mode
#

if (defined(param("debug")))
{
  $debug = param("debug");
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Routing based on Cookie and request content
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#


#
# Determine if the user is logged in
#

if (defined($inputcookiecontent))
{ 
  # Has cookie, let's decode it
  ($user,$password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;

  # Now route based on request
  if (defined(param("act")))
  { 
    $action = param("act");
  }
  # if no action was given, take the user to the list of their portfolios
  else
  {
    $action= "list";
  }
}

#
# If the user isn't logged in, they can get only get to login
#

else
{
  $action="login";
  $run = 0;
}

#
# Determine if a user is trying to run a process or just view a page
#

if (defined(param("run")))
{ 
  $run = param("run") == 1;
}
else
{
  $run = 0;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Login / Logout Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#


#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") { 
  if ($run)
  { 
    #
    # Login attempt
    #
    # Ignore any input cookie.  Just validate user and
    # generate the right output cookie, if any.
    #
    my $submitType;
    ($user,$password,$submitType) = (param('user'),param('password'),param('submitType'));
    $formError = Login_Register($user,$password,$submitType);
    if (defined $formError)
    { 
      # uh oh.  Bogus login attempt.  Make him try again.
      # don't give him a cookie
      $showError = 'inline';
      $action="login";
      $run = 0;
    }
    else
    {
      # if the user's info is OK, then give him a cookie
      # that contains his username and password 
      # the cookie will expire in one hour, forcing him to log in again
      # after one hour of inactivity.
      # Also, land him in the portfolio list screen
      $outputcookiecontent=join("/",$user,$password);
      $action = "list";
      $run = 1;
    }
  }
  else
  {
    #
    # Just a login screen request, but we should toss out any cookie
    # we were given
    #
    undef $inputcookiecontent;
    ($user,$password)=(undef,undef);
  }
} 


#
# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout")
{
  $deletecookie=1;
  $action = "login";
  $user = undef;
  $password = undef;
  $run = 0;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# addPortfolio Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "addPortfolio")
{
  $formError = addPortfolio(param('name'),$user,param('cash'));
  if (defined $formError)
  {
    $showError = 'inline';
  }
  $action = "list";
  $run = 0;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# deletePortfolio Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "deletePortfolio")
{
  $formError = deletePortfolio(param('name'),$user,param('password'));
  if (defined $formError)
  {
    $showError = 'inline';
  }
  $action = "list";
  $run = 0;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# transferMoney Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "transferMoney")
{
  $formError = transferMoney(param('nameMinus'),param('namePlus'),$user,param('cash'));
  if (defined $formError)
  {
    $showError = 'inline';
  }
  $action = "list";
  $run = 0;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# addStockData logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "addStockData")
{
  $stockName = param('stockName');
  $formError = addStockData(param('stockOpen'), param('stockHigh'),
      param('stockLow'), param('stockClose'), param('stockVolume'),
      param('month'), param('day'), param('year'));
  if (defined $formError) {
    $showError = 'inline';
  }
  $action = 'stock';
  #$run = 0;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# History Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "history")
{
  $stockName = param('stockName');
  $startDate = param('startDate');
  $endDate = param('endDate');
  @history = getHistory($stockName, $startDate, $endDate);
  $action = 'stock';
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Cookie Management
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if (defined($outputcookiecontent))
{ 
  my $cookie=cookie(-name=>$cookiename,
        -value=>$outputcookiecontent,
        -expires=>($deletecookie ? '-1h' : '+1h'));
  push @outputcookies, $cookie;
} 


#
# Headers and cookies sent back to client
#

print header(-expires=>'now', -cookie=>\@outputcookies);

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# HTML Generation
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

print << 'HTML';

<!DOCTYPE html>
<html class='no-js' lang='en'>
<head>
  <!-- meta tags needed for foundation -->
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- CSS needed for foundation -->
  <link rel="stylesheet" href="foundation-5/css/normalize.css">
  <link rel="stylesheet" href="foundation-5/css/foundation.min.css">
  <link rel="stylesheet" href="foundation-5/css/foundation-datepicker.css">

  <!-- CSS for Portfolio -->
  <link rel="stylesheet" href="portfolio.css">

  <!-- Javascript needed for foundation -->
  <script src="foundation-5/js/modernizr.js"></script>

  <title>Portfolio</title>

</head>

<body>
  
HTML



# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code.  So, here we only show the form if needed
# 
#
if ($action eq "login")
{ 
  if (!$run)
  { 
    $menuOptions = '';
    $pageContent = << "HTML";
    <br>
    <div class="row">
      <h2>Welcome to Gobias Portfolio Manager</h2>
      <div class="large-12 column">
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="login">
          <input type="hidden" name="run" value="1">
          Email
          <input type="text" name="user">
          <br>
          Password
          <input type="password" name="password" class="error">
          <br><br>
          <input type="submit" value="Login" name="submitType" class="button" style="float:right;">
          <input type="submit" value="Register" name="submitType" class="button" style="float:left;">
        <form>
      </div>
    </div>
HTML
  }
}


#
# LIST
#
# The list of portfolios a user has
#
#
elsif ($action eq "list")
{ 
  $menuOptions = << "HTML";

  <li>
    <a href="#" data-reveal-id="transferMoney">Transfer Money</a>
  </li>
  <li>
    <a href="#" data-reveal-id="deletePortfolio">Delete Portfolio</a>
  </li>
  <li>
    <a href="#" data-reveal-id="addPortfolio">Create Portfolio</a>
  </li>
  <li>
    <a href="portfolio.pl?act=logout">Logout</a>
  </li>

HTML

  my ($str,$error) = getPortfolioList($user,"table");
  if(!$error)
  {
    $pageContent = << "HTML";

    <br>
    <div class="row">
      <div class="large-12 column">
        <h2>Your Portfolios</h2>
        <div class="pageType" style="display:none;">PortfolioList</div>
        $str
      </div>
    </div>

HTML
  }
  else
  {
    # Error message
    $pageContent = << "HTML";

    <div>
        <br>
        <small class="error error-bar">$formError</small>
        <br>
    </div>

HTML
  }
}

#
# PORTFOLIO
# The information in a user's individual portfolio
# 

elsif ($action eq "portfolio")
{
  $portName = param("portName");

  $menuOptions = << "HTML";

   <li>
      <a href="#" data-reveal-id="withdrawStock">Withdraw</a>
    </li>
    <li>
      <a href="#" data-reveal-id="depositStock">Deposit</a>
    </li>
    <li>
      <a href="#" data-reveal-id="sellStock">Sell</a>
    </li>
    <li>
      <a href="#" data-reveal-id="buyStock">Buy</a>
    </li>
    <li>
      <a href="portfolio.pl?act=logout">Logout</a>
    </li>

HTML
  
  my $date = strftime "%m/%d/%Y", localtime;
  my ($cashVal, $stockVal, $totalVal, $strStock, $error) = getPortfolio($user, $portName, "table");
  my ($covarTable, $corrcoeffTable, $c_error) = getCovarienceCorrelation($user, $portName, undef, undef);
  if(!$error and !$c_error)
  {
    $pageContent = << "HTML";

    <br>
    <div class="row">
      <div class="large-12 column">
        <h2 class="pageTitle" name="portfolio">Portfolio $portName</h2>
        <div class="pageType" style="display:none">Portfolio</div>
        <p><b>Cash value:</b> $cashVal</p>
        <p><b>Stock value:</b> $stockVal</p>
        <p><b>Total value:</b> $totalVal</p>
        <dl class="tabs" data-tab>
          <dd class="active"><a href="#stocksPanel">Stocks</a></dd>
          <dd><a href="#covariancePanel">Covariance</a></dd>
          <dd><a href="#corrcoeffPanel">Correlation Coeff</a></dd>
        </dl>
        <div class="tabs-content">
          <div class="content active" id="stocksPanel">
            $strStock
          </div>
          <div class="content" id="covariancePanel">
            <form id="covarTimeForm">
              <div class="row">
                <div class="large-6 column">
                  <label>Start
                    <input class="datePicker" id="startDate" type="text" value="01/01/1925"></input>
                  </label>
                </div>
                <div class="large-6 column">
                  <label>End
                    <input class="datePicker" id="endDate" type="text" value="$date"></input>
                  </label>
                </div>
                <div class="large-12 column">
                  <input type="hidden" id="portName" value="$portName">
                  <input type="submit" class="button" value="Submit" style="float:right;"></input>
                </div>
              </div>
            </form>
            <div id="covarTable">
              $covarTable
            </div>
          </div>
          <div class="content" id="corrcoeffPanel">
            <form id="corrcoeffTimeForm">
              <div class="row">
                <div class="large-6 column">
                  <label>Start
                    <input class="datePicker" id="startDate" type="text" value="01/01/1925"></input>
                  </label>
                </div>
                <div class="large-6 column">
                  <label>End
                    <input class="datePicker" id="endDate" type="text" value="$date"></input>
                  </label>
                </div>
                <div class="large-12 column">
                  <input type="hidden" id="portName" value="$portName">
                  <input type="submit" class="button" value="Submit" style="float:right;"></input>
                </div>
              </div>
            </form>
            <div id="corrcoeffTable">
              $corrcoeffTable
            </div>
          </div>
        </div>
      </div>
    </div>

HTML
  }
  else
  {
    if($error)
    {
      $formError = $error;
    }
    else
    {
      $formError = $c_error;
    }
    $pageContent = << "HTML";

    <div>
        <br>
        <small class="error error-bar">$formError</small>
        <br>
    </div>

HTML
  }
}
elsif ($action eq "stock")
{
  if (defined(param("stockName"))) {
    $stockName = param("stockName");
  }

  $menuOptions = << "HTML";

    <li>
      <a href="#" data-reveal-id="addStockData">Add Stock Data</a>
    </li>
    <li>
      <a href="portfolio.pl?act=logout">Logout</a>
    </li>

HTML
  
  # my ($strStock, $strCov, $error) = getPortfolio($user, $portName, "table");
  my $stockHistory = getStockHistory($user, $stockName);
  if(1) # if !$error
  {
    $pageContent = << "HTML";

      <br>
      <div class="row">
        <div class="large-12 column">
          <h2>$stockName</h2>
          <div class="pageType" style="display:none">Stock</div>
          <p>Price: </p>
          <p>Variation: </p>
          <p>Beta: </p>
          <dl class="tabs" data-tab>
            <dd class="active"><a href="#historyPanel">History</a></dd>
            <dd><a href="#predictionPanel">Prediction</a></dd>
            <dd><a href="#autoTradePanel">Auto-Trade</a></dd>
          </dl>
          <div class="tabs-content">
            <div class="content active" id="historyPanel">
              $stockHistory
            </div>
            <div class="content" id="predictionPanel">
              $stockHistory
            </div>
            <div class="content" id="autoTradePanel">
              $stockHistory
            </div>
          </div>
        </div>
      <div id="historyPage" style="display:none">@history</div>

      </div>

HTML
  }
  else
  {
    $pageContent = << "HTML"

    <div>
      <br>
      <small class="error error-bar">$formError</small>
      <br>
    </div>

HTML
  }
}

# Just get the table of covariences for a given time frame (only used for javascript request)
elsif ($action eq "covar")
{
  my ($portName, $startDate, $endDate) = (param("portName"), param("startDate"), param("endDate"));
  my ($covarTable, $corrcoeffTable, $c_error) = getCovarienceCorrelation($user, $portName, $startDate, $endDate);
  $pageContent = << "HTML"
    <div id="covarTable">
      $covarTable
    </div>

HTML
}

# Just get the table of correlation coefficients for a given time frame (only used for javascript request)
elsif ($action eq "corrcoeff")
{
  my ($portName, $startDate, $endDate) = (param("portName"), param("startDate"), param("endDate"));
  my ($covarTable, $corrcoeffTable, $c_error) = getCovarienceCorrelation($user, $portName, $startDate, $endDate);
  $pageContent = << "HTML"
    <div id="corrcoeffTable">
      $corrcoeffTable
    </div>

HTML
}

else
{
  print "Error: Invalid action"
}

#
# PRINT OUT ALL HTML HERE
#

my $dateNums = '';

for(my $i=1; $i<=31; $i++) {
  $dateNums = $dateNums . '<option value="' . $i . '">' . $i . '</option>';
}

  print << "HTML";

  <!-- Menu bar -->
  <div class="fixed top-bar-bottom-border">
    <nav class="top-bar" data-topbar data-options="scrolltop:false" role="navigation">
      <ul class="title-area">
        <li class="name">
          <h1 class="nav-title">
            <a href="#" class="nav-title">Gobias</a>
        </li>
        <li class="toggle-topbar menu-icon">
          <a href="#"><span></span></a>
        </li>
      </ul>
      <section class="top-bar-section">
        <ul class="right">
          $menuOptions
        </ul>
      </section>
    </nav>
  </div>

  <!-- Error Message -->
  <div style="display:$showError;">
      <br>
      <small class="error error-bar">$formError</small>
      <br>
  </div>

  <!-- MODALS GALORE - all modals placed here -->

  <!-- Add Portfolio -->
  <div id="addPortfolio" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Create a Portfolio</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="addPortfolio">
          <input type="hidden" name="run" value="1">
          Name
          <input type="text" name="name">
          Initial Cash Value
          <input type="text" name="cash">
          <br><br>
          <input type="submit" value="Create" class="button" style="float:right;">
        </form>
      </div>
    </div>
    <a class="close-reveal-modal">&#215;</a>
  </div>

  <!-- Delete Portfolio -->
  <div id="deletePortfolio" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Delete a Portfolio</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="deletePortfolio">
          <input type="hidden" name="run" value="1">
          Name
          <input type="text" name="name">
          Password
          <input type="password" name="password">
          <br><br>
          <input type="submit" value="Delete" class="button" style="float:right;">
        </form>
      </div>
    </div>
    <a class="close-reveal-modal">&#215;</a>
  </div>

  <!-- Transfer Money -->
  <div id="transferMoney" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Transfer Money</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="transferMoney">
          <input type="hidden" name="run" value="1">
          From
          <input type="text" name="nameMinus">
          To
          <input type="text" name="namePlus">
          Amount
          <input type="text" name="cash">
          <br><br>
          <input type="submit" value="Transfer" class="button" style="float:right;">
        </form>
      </div>
    </div>
    <a class="close-reveal-modal">&#215;</a>
  </div>

  <!-- Add Stock Data -->
  <div id="addStockData" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Add new stock data for $stockName</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="addStockData">
          <input type="hidden" name="stockName" value=$stockName>
          Open
          <input type="text" name="stockOpen">
          High
          <input type="text" name="stockHigh">
          Low
          <input type="text" name="stockLow">
          Close
          <input type="text" name="stockClose">
          Volume
          <input type="text" name="stockVolume">
      </div>
      <div class="large-4 column">
        <label>Month
          <select name="month">
            <option value='1'>January</option>
            <option value='2'>February</option>
            <option value='3'>March</option>
            <option value='4'>April</option>
            <option value='5'>May</option>
            <option value='6'>June</option>
            <option value='7'>July</option>
            <option value='8'>August</option>
            <option value='9'>September</option>
            <option value='10'>October</option>
            <option value='11'>November</option>
            <option value='12'>December</option>
          </select>
        </label>
      </div>
      <div class="large-2 column">
        <label>Day
          <select name="day">
            $dateNums
          </select>
        </label>
      </div>
      <div class="large-3 column">
        <label>Year 
          <select name="year">
            <option value='2006'>2006</option>
            <option value='2007'>2007</option>
            <option value='2008'>2008</option>
            <option value='2009'>2009</option>
            <option value='2010'>2010</option>
            <option value='2011'>2011</option>
            <option value='2012'>2012</option>
            <option value='2013'>2013</option>
            <option value='2014'>2014</option>
          </select>
        </label>
      </div>
      <div class="large-3 column"></div>
    </div>
          <br><br>
          <input type="submit" value="Submit" class="button" style="float:right;">
        </form>
    <a class="close-reveal-modal">&#215;</a>
  </div>


  <!-- PAGE CONTENT -->
  <br>
  $pageContent

  <!-- Javascript needed for foundation -->
  <script src="foundation-5/js/jquery.js"></script>
  <script src="foundation-5/js/foundation.min.js"></script>
  <script src="foundation-5/js/foundation-datepicker.js"></script>
  <script src="foundation-5/js/Chart.js"></script>
  <script>\$(document).foundation();</script>
  <script src="portfolio.js"></script>
</body>
</html>

HTML



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Sub Routines
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#
# Transfer money from one portfolio to another
#

sub getCovarienceCorrelation
{
  my ($user, $portfolioName, $start, $end) = @_;
  my @symbols;

  eval
  {
    @symbols = ExecSQL($dbuser,$dbpasswd, "select symbol from port_stocksUser where email=? and name=?","COL",$user,$portfolioName);
  };
  if ($@)
  {
    return (undef,undef,$@);
  }

  # initialize variables
  my %covar;
  my %corrcoeff;
  my $count;
  my $mean_f1;
  my $std_f1;
  my $mean_f2;
  my $std_f2;

  # For each stock symbol
  for (my $i=0;$i<=$#symbols;$i++)
  {
    # Store the stock symbol in s1
    my $s1=$symbols[$i];
    # For each other stock symbol after s1
    for (my $j=$i; $j<=$#symbols; $j++)
    {
      # Store the other stock symbol in s2
      my $s2=$symbols[$j];

      # Get means and vars for the individual columns that match      

      if (defined $start and defined $end)
      { # Get for specific time range
        eval
        {
          ($count, $mean_f1,$std_f1, $mean_f2, $std_f2) = ExecSQL($dbuser,$dbpasswd,"select count(*), avg(s1.close),stddev(s1.close), avg(s2.close), stddev(s2.close) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp = s2.timestamp where s1.symbol=? and s2.symbol=? and s1.timestamp>=? and s1.timestamp<=?","ROW",$s1,$s2,$start,$end);
        };
      }
      else
      { # Get for all time
        eval
        {
          ($count, $mean_f1,$std_f1, $mean_f2, $std_f2) = ExecSQL($dbuser,$dbpasswd,"select count(*), avg(s1.close),stddev(s1.close), avg(s2.close), stddev(s2.close) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp = s2.timestamp where s1.symbol=? and s2.symbol=?","ROW",$s1,$s2);
        };
      }
      if ($@)
      {
        return (undef,undef,$@);
      }

      #skip this pair if there isn't enough data

      if ($count<30)
      { # not enough data
        $covar{$s1}{$s2}='NODAT';
        $corrcoeff{$s1}{$s2}='NODAT';
      }

      else
      { # Get the covariance

        if (defined $start and defined $end)
        { # Get for specific time range
          eval
          {
            ($covar{$s1}{$s2}) = ExecSQL($dbuser,$dbpasswd,"select avg( (s1.close -  ?)*(s2.close - ?) ) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp=s2.timestamp where s1.symbol=? and s2.symbol=? and s1.timestamp>=? and s1.timestamp<=?","COL",$mean_f1,$mean_f2,$s1,$s2,$start,$end)
          };
        }
        else
        { # Get for all time
          eval
          {
            ($covar{$s1}{$s2}) = ExecSQL($dbuser,$dbpasswd,"select avg( (s1.close - ?)*(s2.close - ?) ) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp=s2.timestamp where s1.symbol=? and s2.symbol=?", "COL",$mean_f1,$mean_f2,$s1,$s2)
          };
        }
        if ($@)
        {
          return (undef,undef,$@);
        }

        #and the correlationcoeff

        $corrcoeff{$s1}{$s2} = $covar{$s1}{$s2}/($std_f1*$std_f2);
      }
    }
  }

  # Create output covar table-html

  # First table row (all stock symbols)
  my $covarTable = "<table style='width:100%' border>\n"."<tbody>\n"."<tr>\n"."<td></td>\n";
  foreach(@symbols)
  {
    $covarTable .= "<th>$_</th>\n";
  }
  $covarTable .= "</tr>\n";

  # All other rows
  for (my $i=0;$i<=$#symbols;$i++)
  {
    # Start new table row
    $covarTable .= "<tr>\n";
    # First column is always the stock symbol
    my $s1 = $symbols[$i];
    $covarTable .= "<th>$s1</th>\n";

    # For all other columns
    for (my $j=0; $j<=$#symbols;$j++)
    {
      # If stock i has already been compared to stock j
      if ($i>$j)
      { # Print an empty square
        $covarTable .= "<td></td>\n";
      }
      else
      { #Print a square filled with the covarience data
        my $s2=$symbols[$j];
        my $data = $covar{$s1}{$s2} eq "NODAT" ? "NODAT" : sprintf('%3.2f',$covar{$s1}{$s2});
        $covarTable .= "<td>$data</td>\n";
      }
    }
    $covarTable .= "</tr>\n";
  }
  $covarTable .= "</tbody>\n"."</table>\n";

  # Create output covar table-html

  # First table row (all stock symbols)
  my $corrcoeffTable = "<table style='width:100%' border>\n"."<tbody>\n"."<tr>\n"."<td></td>\n";
  foreach(@symbols)
  {
    $corrcoeffTable .= "<th>$_</th>\n";
  }
  $corrcoeffTable .= "</tr>\n";

  # All other rows
  for (my $i=0;$i<=$#symbols;$i++)
  {
    # Start new table row
    $corrcoeffTable .= "<tr>\n";
    # First column is always the stock symbol
    my $s1 = $symbols[$i];
    $corrcoeffTable .= "<th>$s1</th>\n";

    # For all other columns
    for (my $j=0; $j<=$#symbols;$j++)
    {
      # If stock i has already been compared to stock j
      if ($i>$j)
      { # Print an empty square
        $corrcoeffTable .= "<td></td>\n";
      }
      else
      { #Print a square filled with the covarience data
        my $s2=$symbols[$j];
        my $data = $corrcoeff{$s1}{$s2} eq "NODAT" ? "NODAT" : sprintf('%3.2f',$corrcoeff{$s1}{$s2});
        $corrcoeffTable .= "<td>$data</td>\n";
      }
    }
    $corrcoeffTable .= "</tr>\n";
  }
  $corrcoeffTable .= "</tbody>\n"."</table>\n";

  return ($covarTable, $corrcoeffTable,undef);
}

#
# Transfer money from one portfolio to another
#

sub transferMoney
{
  my ($nameMinus, $namePlus, $user, $cash) = @_;

  # Make sure cash is a number
  if (!looks_like_number($cash))
  {
    return "Please enter a pure numeric value for \"Amount\"";
  }

  # Make sure that both portfolio names are valid
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from port_portfolio where email=? and name in (?,?)","COL",$user,$nameMinus,$namePlus);};
  if($@ or $col[0]<2)
  {
    return "There was a problem when transfering money. Please try again";
  }

  # Deduct money from one portfolio (will return with error if insufficient funds)
  eval {ExecSQL($dbuser,$dbpasswd, "update port_portfolio set cash = cash - ? where name=? and email=?",undef,$cash,$nameMinus,$user);};
  if($@)
  {
    return "There was a problem when transfering money. Please try again";
  }

  # Add money to the other portfolio
  eval {ExecSQL($dbuser,$dbpasswd, "update port_portfolio set cash = cash + ? where name=? and email=?",undef,$cash,$namePlus,$user);};
  if($@)
  {
    return "There was a problem when transfering money. Please try again";
  }

  return; 
}

#
# Allow user to add stock data on the day of something
#

sub addStockData
{
  my ($open, $high, $low, $close, $volume, $month, $day, $year) = @_;
  # Timestamp after closing time of stock market
  $timestamp = timelocal(0, 59, 23, $day, $month-1, $year);

  eval{ExecSQL($dbuser, $dbpasswd, "insert into port_stocksDaily (symbol, timestamp, open, high, low, close, volume) values (?, ?, ?, ?, ?, ?, ?)", undef, $stockName, $timestamp, $open, $high, $low, $close, $volume);};

  return;
}

#
# Delete a portfolio for a user
#

sub deletePortfolio
{
  my ($name, $user, $password) = @_;
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from port_users where email=? and password=?","COL",$user,$password);};
  if($@ or $col[0]<=0)
  {
    return "Incorrect password. Please try again";
  }
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from port_portfolio where name=? and email=?","COL",$name,$user);};
  if($@ or $col[0]<=0)
  {
    return "No portfolio with that name exists. Please try again.";
  }

  eval {ExecSQL($dbuser,$dbpasswd, "delete from port_portfolio where name=? and email=?",undef,$name,$user);};
  if($@)
  {
    return "There was a problem when deleting a portfolio. Please try again";
  }
  else
  {
    return;
  }
}

#
# Add a new portfolio for a user
#

sub addPortfolio
{
  my ($name, $user, $cash) = @_;
  if (!looks_like_number($cash))
  {
    return "Please enter a pure numeric value for \"Initial Cash Value\"";
  }

  eval {ExecSQL($dbuser,$dbpasswd, "insert into port_portfolio (name, email, cash) values (?,?,?)",undef,$name,$user,$cash);};
  if($@)
  {
    return "There was a problem when creating a portfolio. Please try again";
  }
  else
  {
    return;
  }
}

#
# Retrieve portfolio list for the list page
#

sub getPortfolioList
{
  my ($user, $format) = @_;
  my @portfolioRows;

  # Get name and cash value of each portfolio
  eval
  {
    @portfolioRows = ExecSQL($dbuser, $dbpasswd, "select name, cash from port_portfolio where email = ?", undef, $user);
  };
  if ($@)
  { 
    return (undef,$@);
  }

  # Get stock value and total value of each portfolio

  my $portfolioName;
  my $portfolioCash;
  my @stockRows;
  my $stockSymbol;
  my $stockAmount;
  my @stockPrice;
  my $portfolioStockValue;

  # For each portfolio...
  foreach(@portfolioRows)
  {
    # Initialize the stock value to 0 and get the portfolio name and cash value
    $portfolioStockValue = 0;
    $portfolioName = $_->[0];
    $portfolioCash = $_->[1];
    # Get the list of stocks for the portfolio
    eval
    {
      @stockRows = ExecSQL($dbuser, $dbpasswd, "select symbol, amount from port_stocksUser where name = ? and email = ?", undef, $portfolioName, $user);
    };
    if ($@)
    { 
      return (undef,$@);
    }
    # For each stock in the portfolio's list of stocks
    foreach(@stockRows)
    {
      # Get the stock's symbol and how much is in the portfolio
      $stockSymbol = $_->[0];
      $stockAmount = $_->[1];
      # Get the most recent price of the stock
      eval
      {
        @stockPrice = ExecSQL($dbuser, $dbpasswd, "select close from (select close, timestamp from port_stocksDaily where symbol = ?) sd1 natural join (select max(timestamp) timestamp from port_stocksDaily where symbol = ?) sd2", "COL",$stockSymbol, $stockSymbol);
      };
      if ($@)
      { 
        return (undef,$@);
      }
      # Add to the running total of the portfolio's stock value
      $portfolioStockValue += $stockPrice[0]*$stockAmount;
    }
    # Add the stock value and the total value to the portfolio's "row"
    push(@$_, $portfolioStockValue);
    push(@$_, $portfolioStockValue+$portfolioCash);
  }

  # Create a table of the portfolio's name, cash value, stock value, and total value
  if ($format eq "table")
  { 
    return (MakeTable("Portfolios", "2DClickable",
      ["Name", "Cash Value","Stock Value","Total Value"],
      @portfolioRows),$@);
  }
  else 
  {
    return (MakeRaw("individual_data","2D",@portfolioRows),$@);
  }
}

#
# Retrieve info for single portfolio
# 
sub getPortfolio
{
  my ($user, $portName, $format) = @_;

  # Get the cash value of the portfolio
  my @cash;
  eval
  {
    @cash = ExecSQL($dbuser, $dbpasswd, "select cash from port_portfolio where email = ?", "ROW", $user);
  };
  if ($@)
  { 
    return (undef,undef,undef,undef,$@);
  }
  my $portfolioCash = $cash[0];

  my @stockRows;
  eval
  {
    @stockRows = ExecSQL($dbuser, $dbpasswd, "select symbol, amount from port_stocksUser where email = ? and name = ?", undef, $user, $portName);
  };
  if ($@)
  { 
    return (undef,undef,undef,undef, $@);
  }

  # Initialize variables
  my $stockSymbol;
  my $stockAmount;
  my @coeffVariation;
  my @stockPrice;
  my $portfolioStockValue = 0;
  my ($mean_f1,$std_f1, $mean_f2, $std_f2);
  my $covar;
  my $beta;
  my $count;
  my $entries;

  foreach(@stockRows)
  {
    # Get the stock's symbol and how much is in the portfolio
    $stockSymbol = $_->[0];
    $stockAmount = $_->[1];
    # Get the most recent price of the stock
    eval
    {
      @stockPrice = ExecSQL($dbuser, $dbpasswd, "select close from (select close, timestamp from port_stocksDaily where symbol = ?) sd1 natural join (select max(timestamp) timestamp from port_stocksDaily where symbol = ?) sd2", "COL",$stockSymbol, $stockSymbol);
    };
    if ($@)
    { 
      return (undef,undef,undef,undef,$@);
    }
    # Add to the running total of the portfolio's stock value
    $portfolioStockValue += $stockPrice[0]*$stockAmount;
    # push the stock's price and value into the stockRow
    push(@$_, sprintf('%3.2f',$stockPrice[0]));
    push(@$_, sprintf('%3.2f',$stockPrice[0]*$stockAmount));

    # Get the stock's coefficient of variation
    eval
    {
      @coeffVariation = ExecSQL($dbuser, $dbpasswd, "select stddev(close)/avg(close) from port_stocksDaily where symbol=?","ROW",$stockSymbol);
    };
    if ($@)
    { 
      return (undef,undef,undef,undef,$@);
    }
    # Push the stock's coefficient of variation into the stockRow
    push(@$_, sprintf('%3.4f',$coeffVariation[0]));

    # Get the stocks beta

    # Find out if the beta for this stock has a cached value for the stock data currently available
    eval
    {
      ($count) = ExecSQL($dbuser,$dbpasswd,"select count(*) from port_stocksDaily where symbol=?","COL",$stockSymbol);
      ($entries, $beta) = ExecSQL($dbuser,$dbpasswd,"select entries, beta from port_betaCache where symbol=?","ROW",$stockSymbol);
    };
    if ($@)
    {
      return (undef,undef,undef,undef,$@);
    }
    # If the beta value hasn't been cached since new data was added, calculate it
    if($count != $entries)
    {
      eval
      {
        ($mean_f1,$std_f1, $mean_f2, $std_f2) = ExecSQL($dbuser,$dbpasswd,"select avg(s1.close),stddev(s1.close), avg(s2.close), stddev(s2.close) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp = s2.timestamp where s1.symbol=?","ROW",$stockSymbol);
      };
      if ($@)
      { 
        return (undef,undef,undef,undef,$@);
      }
      eval
      {
        ($covar) = ExecSQL($dbuser,$dbpasswd,"select avg( (s1.close - ?)*(s2.close - ?) ) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp=s2.timestamp where s1.symbol=?", "COL",$mean_f1,$mean_f2,$stockSymbol);
      };
      if ($@)
      { 
        return (undef,undef,undef,undef,$@);
      }
      $beta = $covar/($std_f1*$std_f2);

      # Store the beta value in the cache
      eval
      {
        if (defined $entries)
        {
          ExecSQL($dbuser,$dbpasswd,"update port_betaCache set symbol=?, beta=?, entries=? where symbol=?", undef,$stockSymbol, $beta, $count, $stockSymbol);
        }
        else
        {
          ExecSQL($dbuser,$dbpasswd,"insert into port_betaCache (symbol, beta, entries) values (?,?,?)", undef,$stockSymbol, $beta, $count);          
        }
      };
      if ($@)
      { 
        return (undef,undef,undef,undef,$@);
      }
    }

    # Push the stock's beta into the stockRow
    push(@$_, sprintf('%3.4f',$beta));

  }

  # Calculate total portfolio value
  my $portfolioTotalValue = sprintf('%3.2f',$portfolioCash + $portfolioStockValue);

  # Round off cash value and stock value
  $portfolioCash = sprintf('%3.2f',$portfolioCash);
  $portfolioStockValue = sprintf('%3.2f',$portfolioStockValue);
 
  return ($portfolioCash,
    $portfolioStockValue,
    $portfolioTotalValue,
    MakeTable("StockPortfolio", "2DClickable", ["Symbol", "Quantity", "Price", "Value", "COV", "Beta"],
    @stockRows),
    $@);
    
}

sub getStockHistory
{
  my ($user, $stock) = @_;

    my $history = << "HTML";
    <p>Insert a date range before 2006. Or enter your own stock data.</p>
    <form id="stockHistoryForm" action="portfolio.pl" method="get">
      <input type="hidden" name="act" value="history">
      <input type="hidden" name="stockName" value=$stock>
      <div class="row">
        <div class="large-4 columns">
          <label>Start date
            <input class="datePicker" type="text" name="startDate" value="$startDate">
          </label>
        </div>
        <div class="large-4 columns">
          <label>End date
            <input class="datePicker" type="text" name="endDate" value="$endDate">
          </label>
        </div>
        <div class="large-4 columns"></div>
      </div>
      <div class="row">
        <input type="submit" class="button" value="Update">
      </div>
    </form>
    <canvas id="stockHistoryGraph" width="400" height="400"></canvas>
HTML

  # now we need a graph plotting time for these dates as well as their price
  return $history;
}

sub getHistory
{
  my ($stock, $start, $end) = @_;
  # Parse date strings and convert to timestamp
  # Then query database for proper times and stuff
  my ($startMonth, $startDay, $startYear) = split(/\//, $start);
  my ($endMonth, $endDay, $endYear) = split(/\//, $end);

  # Beginning of first day
  $startTimestamp = timelocal(0, 0, 0, $startDay, $startMonth-1, $startYear);
  # End of last day
  $endTimestamp = timelocal(0, 59, 23, $endDay, $endMonth-1, $endYear);

  # Now basically query the database for close dates for apple between these timestamps
  my @col;
  eval{@col = ExecSQL($dbuser, $dbpasswd, "select close from port_stocksDaily where timestamp>? and timestamp<? and symbol=?", "COL", $startTimestamp, $endTimestamp, $stock);};

  return @col;
}

#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
sub Login_Register
{
  my $submitType = pop @_;
  if ($submitType eq "Login")
  {
    my @col;
    eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from port_users where email=? and password=?","COL",$user,$password);};
    if($@ or $col[0]<=0)
    {
      return "There was a problem when logging in. Please try again";
    }
    else
    {
      return;
    }
  }
  else
  {
    my ($user,$password)=@_;
    eval {ExecSQL($dbuser,$dbpasswd, "insert into port_users (email, password) values (?,?)",undef,$user,$password);};
    if($@)
    {
      return "There was a problem when registering. Please try again";
    }
    else
    {
      return;
    }
  }
}


#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
  my ($id,$type,$headerlistref,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  if ((defined $headerlistref) || ($#list>=0)) {
    # if there is, begin a table
    #
    if ($type ne "2DClickable") {
      $out="<table id=\"$id\" border>";
    } else {
      $out="<table id=\"id\" class=\"clickable-row\" style='width:100%' border>";
    }
    #
    # if there is a header list, then output it in bold
    #
    if (defined $headerlistref) { 
      $out.="<tr>".join("",(map {"<th>$_</th>"} @{$headerlistref}))."</tr>";
    }
    #
    # If it's a single row, just output it in an obvious way
    #
    if ($type eq "ROW") { 
      #
      # map {code} @list means "apply this code to every member of the list
      # and return the modified list.  $_ is the current list member
      #
      $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
    } elsif ($type eq "COL") { 
      #
      # ditto for a single column
      #
      $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
    } elsif ($type eq "2D") { 
      #
      # For a 2D table, it's a bit more complicated...
      #
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    } else {
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    }
    $out.="</table>";
  } else {
    # if no header row or list, then just say none.
    $out.="(none)";
  }
  return $out;
}


#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
  my ($id, $type,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  $out="<pre id=\"$id\">\n";
  #
  # If it's a single row, just output it in an obvious way
  #
  if ($type eq "ROW") { 
    #
    # map {code} @list means "apply this code to every member of the list
    # and return the modified list.  $_ is the current list member
    #
    $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } elsif ($type eq "COL") { 
    #
    # ditto for a single column
    #
    $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } else {
    #
    # For a 2D table
    #
    foreach my $r (@list) { 
      $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
      $out.="\n";
    }
  }
  $out.="</pre>\n";
  return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#

sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  if ($debug) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
    push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  }
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set)
    # and then die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    }
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    #
    # If prepare failed, then record reason to sqloutput and then die
    #
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    #
    # if exec failed, record to sqlout and die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  #
  # The rest assumes that the data will be forthcoming.
  #
  #
  my @data;
  if (defined $type and $type eq "ROW") { 
    @data=$sth->fetchrow_array();
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  my @ret;
  while (@data=$sth->fetchrow_array()) {
    push @ret, [@data];
  }
  if (defined $type and $type eq "COL") { 
    @data = map {$_->[0]} @ret;
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  $sth->finish();
  if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
  $dbh->disconnect();
  return @ret;
}


######################################################################
#
# Nothing important after this
#
######################################################################

# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
}

