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
my $modalViews = undef;
my $pageContent = undef;
my $timestamp = undef;
my $startTimestamp = undef;
my $endTimestamp = undef;
my @history = undef;
my @tsHistory = undef;
my $predictions = undef;

my $startDate = '11/01/2005';
my $endDate = '11/10/2005';

#AutoTrading variables
my $total = undef;
my $startCash = undef;
my $roi = undef; #without trading cost
my $roiAnnual = undef; #without trading cost
my $totalAfterTradingCost = undef;
my $roiAtCost = undef; #with trading cost
my $roiAnnualAtCost = undef; #with trading cost
my $daysTraded = undef;
my $tradeCost = undef;


#Keep track of active tab
my $historyActive = undef;
my $predictionActive = undef;
my $autoTradeActive = undef;
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
# withdrawMoney & depositMoney Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "withdrawMoney" or $action eq "depositMoney")
{
  $formError = withdrawDepostMoney(param('portName'),param('cash'), $action,$user);
  if (defined $formError)
  {
    $showError = 'inline';
  }
  $action = "portfolio";
  $run = 0;
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# buyStock & sellStock Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "buyStock" or $action eq "sellStock")
{
  $formError = buySellStock(param('portName'), param('symbol'), param('amount'), $action, $user);
  if (defined $formError)
  {
    $showError = 'inline';
  }
  $action = "portfolio";
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
  $historyActive = 'active';
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Autotrade Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "autotrade")
{
	$stockName = param('stockName');
	$startDate = param('startDate');
	$endDate = param('endDate');
	$startCash = param('startCash');
	$tradeCost = param('tradeCost');
	$action = 'stock';
	($total, $roi, $roiAnnual, $totalAfterTradingCost,
		$roiAtCost, $roiAnnualAtCost, $daysTraded) = 
						autoTrade($stockName, $startDate, $endDate, $startCash,
							$tradeCost);

	$autoTradeActive = 'active';

}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Prediction Logic
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

if ($action eq "predictions") {
  $stockName = param('stockName');
  my $steps = param('steps');

  $predictions = getStockPredictions($stockName, $steps);
  $action = 'stock';

  $predictionActive = 'active';
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
    <div class="row text-center">
      <div class="large-2 column">
        <a href="Story Board.pdf" download="Story Board.pdf">Story Board</a>
      </div>
      <div class="large-2 column">
        <a href="Story Board.pdf" download="Story Board.pdf">ER Diagram</a>
      </div>
      <div class="large-2 column">
        <a href="Story Board.pdf" download="Story Board.pdf">Relational Model</a>
      </div>
      <div class="large-2 column">
        <a href="setup.sql" download="setup.sql">SQL DDL</a>
      </div>
      <div class="large-2 column">
        <a href="sql_querries.txt" download="sql_querries.txt">SQL DML, DQL</a>
      </div>
      <div class="large-2 column">
        <a href="portfolio.txt" download="portfolio.txt">Website Code</a>
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

  $modalViews = << "HTML";

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
      <a href="#" data-reveal-id="withdrawMoney">Withdraw</a>
    </li>
    <li>
      <a href="#" data-reveal-id="depositMoney">Deposit</a>
    </li>
    <li>
      <a href="#" data-reveal-id="buyStock">Buy</a>
    </li>
    <li>
      <a href="#" data-reveal-id="sellStock">Sell</a>
    </li>
    <li>
      <a href="portfolio.pl?act=logout">Logout</a>
    </li>

HTML

  $modalViews = << "HTML";

  <!-- Withdaw Money -->
  <div id="withdrawMoney" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Withdaw Money</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="withdrawMoney">
          <input type="hidden" name="portName" value="$portName">
          <input type="hidden" name="run" value="1">
          Amount
          <input type="text" name="cash">
          <br><br>
          <input type="submit" value="Withdaw" class="button" style="float:right;">
        </form>
      </div>
    </div>
    <a class="close-reveal-modal">&#215;</a>
  </div>

  <!-- Deposit Money -->
  <div id="depositMoney" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Deposit Money</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="depositMoney">
          <input type="hidden" name="portName" value="$portName">
          <input type="hidden" name="run" value="1">
          Amount
          <input type="text" name="cash">
          <br><br>
          <input type="submit" value="Deposit" class="button" style="float:right;">
        </form>
      </div>
    </div>
    <a class="close-reveal-modal">&#215;</a>
  </div>

  <!-- Buy Stock -->
  <div id="buyStock" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Buy Stock</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="buyStock">
          <input type="hidden" name="portName" value="$portName">
          <input type="hidden" name="run" value="1">
          Symbol
          <input type="text" name="symbol">
          Amount
          <input type="text" name="amount">
          <br><br>
          <input type="submit" value="Buy" class="button" style="float:right;">
        </form>
      </div>
    </div>
    <a class="close-reveal-modal">&#215;</a>
  </div>

  <!-- Sell Stock -->
  <div id="sellStock" class="reveal-modal" data-reveal>
    <div class="row">
      <div class="large-12 column">
        <h2>Sell Stock</h2>
        <form action="portfolio.pl" method="get">
          <input type="hidden" name="act" value="sellStock">
          <input type="hidden" name="portName" value="$portName">
          <input type="hidden" name="run" value="1">
          Symbol
          <input type="text" name="symbol">
          Amount
          <input type="text" name="amount">
          <br><br>
          <input type="submit" value="Sell" class="button" style="float:right;">
        </form>
      </div>
    </div>
    <a class="close-reveal-modal">&#215;</a>
  </div>

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

  my $dateNums = '';

  for(my $i=1; $i<=31; $i++) {
    $dateNums = $dateNums . '<option value="' . $i . '">' . $i . '</option>';
  }

  $modalViews = << "HTML";

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

HTML
  
  # my ($strStock, $strCov, $error) = getPortfolio($user, $portName, "table");
  my $stockHistory = getStockHistory($user, $stockName);
  my $autoTrade = getAutoTrade($user, $stockName);
  my ($price, $variation, $beta, $formError) = getStockValues($stockName);
  if($stockHistory && $autoTrade && $price) # if !$error
  {
    $pageContent = << "HTML";

      <br>
      <div class="row">
        <div class="large-12 column">
          <h2>$stockName</h2>
          <div class="pageType" style="display:none">Stock</div>
          <p><b>Price:</b> $price</p>
          <p><b>Variation:</b> $variation</p>
          <p><b>Beta:</b> $beta</p>
          <dl class="tabs" data-tab>
            <dd class="$historyActive"><a href="#historyPanel">History</a></dd>
            <dd class="$predictionActive"><a href="#predictionPanel">Prediction</a></dd>
            <dd class="$autoTradeActive"><a href="#autoTradePanel">Auto-Trade</a></dd>
          </dl>
          <div class="tabs-content">
            <div class="content $historyActive" id="historyPanel">
              $stockHistory
            </div>
            <div class="content $predictionActive" id="predictionPanel">
              <form action="portfolio.pl" method="get">
                <input type="hidden" name="act" value="predictions">
                <input type="hidden" name="stockName" value="$stockName">
                <label>Number of steps
                  <input type="text" name="steps" value="">
                </label>
                <input type="submit" class="button" value="Submit">
              </form>
              <div id="predictions" style="display:none">$predictions</div>
              <div id="predictionTitle"></div>
              <div id="predictionsChartDiv">
                <canvas id="predictionsChart"></canvas>
              </div>
            </div>
            <div class="content $autoTradeActive" id="autoTradePanel">
              $autoTrade
            </div>
          </div>
        </div>
      <div id="historyPage" style="display:none">@history</div>
      <div id="historyPageTs" style="display:none">@tsHistory</div> 

      </div>

HTML
  }
  else
  {
    $pageContent = << "HTML"

    <div>
      <br>
      <small class="error error-bar"></small>
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
  $modalViews


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
# Transfer money out of a portfolio or into a portfolio
#

sub withdrawDepostMoney
{
  my ($name, $cash, $option, $user) = @_;

  # Make sure cash is a number
  if (!looks_like_number($cash))
  {
    return "Please enter a pure numeric value for \"Amount\"";
  }

  # get the poper operator
  my $operator;
  if ($option eq "depositMoney")
  {
    $operator = '+';
  }
  elsif ($option eq "withdrawMoney")
  {
    $operator = '-';
  }
  else
  {
    return "There was a problem when transfering money. Please try again";
  }

  # Deduct/add money from/to the portfolio (will return with error if insufficient funds)
  eval {ExecSQL($dbuser,$dbpasswd, "update port_portfolio set cash = cash ".$operator." ? where name=? and email=?",undef,$cash,$name,$user);};
  if($@)
  {
    return "There was a problem when transfering money. Please try again";
  }

  return;
}

sub buySellStock
{
  my ($name, $symbol, $amount, $option, $user) = @_;

  # Make sure cash is a number
  if (!looks_like_number($amount))
  {
    return "Please enter a pure numeric value for \"Amount\"";
  }

  # Make sure the stock symbol exists in the database
  my $col;
  eval
  {
    ($col)=ExecSQL($dbuser,$dbpasswd, "select count(*) from port_stocksDaily where symbol=? and rownum = 1","COL",$symbol);
  };
  if($@ or $col<=0)
  {
    return "No stock with symbol: $symbol exists. Please try again.";
  }

  # Get the most recent price of the stock
  my $stockPrice;
  eval
  {
    ($stockPrice) = ExecSQL($dbuser, $dbpasswd, "select close from (select close, timestamp from port_stocksDaily where symbol = ?) sd1 natural join (select max(timestamp) timestamp from port_stocksDaily where symbol = ?) sd2", "ROW",$symbol, $symbol);
  };
  if ($@)
  { 
    return $@;
  }

  # get the cash amount that the user will lose/gain from buying/selling the stocks
  my $cash = $stockPrice*$amount;

  # Buy or sell the stock
  if ($option eq "buyStock")
  {
    # Deduct money from the portfolio (will return with error if insufficient funds)
    eval {
		ExecSQL($dbuser,$dbpasswd, "SAVEPOINT buy_save",undef);
		return $@ if ($@);
		ExecSQL($dbuser,$dbpasswd, "update port_portfolio set cash = cash - ? where name=? and email=?",undef,$cash,$name,$user);};
    if($@)
    {
      return $@;
    }
    # See if the user owns some of this stock
    my $stockCount;
    eval
    {
      ($stockCount) = ExecSQL($dbuser,$dbpasswd, "select count(*) from port_stocksUser where name=? and email=? and symbol=?","ROW",$name,$user,$symbol);
    };
    if($@)
    {
		my $error = $@;
		eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to buy_save",undef);};
      return $error;
    }
    # Add stocks to the portfolio
    if($stockCount == 0)
    {
      eval {ExecSQL($dbuser,$dbpasswd, "insert into port_stocksUser (symbol, amount, name, email) values (?,?,?,?)",undef,$symbol,$amount,$name,$user);};
    }
    else
    {
      eval {ExecSQL($dbuser,$dbpasswd, "update port_stocksUser set amount = amount + ? where name=? and email=? and symbol=?",undef,$amount,$name,$user,$symbol);};      
    }
    if($@)
    {
		my $error = $@;
		eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to buy_save",undef);};
        return $error;
    }else{		
		eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to buy_save",undef);};
		eval{ExecSQL($dbuser,$dbpasswd,"COMMIT",undef);};
		return $@ if $@;
	}
  }
  elsif ($option eq "sellStock")
  {
    # Make sure the user owns some of this stock
    my $stockCount;
    eval
    {
		ExecSQL($dbuser,$dbpasswd, "SAVEPOINT sell_save",undef);
		return $@ if ($@);
      ($stockCount) = ExecSQL($dbuser,$dbpasswd, "select count(*) from port_stocksUser where name=? and email=? and symbol=?","ROW",$name,$user,$symbol);
    };
    if($@)
    {
      return $@;
    }
    if ($stockCount == 0)
    {
      return "You do not own any stock with symbol: $symbol. Please try again.";
    }

    # Deduct stocks from the portfolio (will return with error if insufficient amount)
    eval {ExecSQL($dbuser,$dbpasswd, "update port_stocksUser set amount = amount - ? where name=? and email=? and symbol=?",undef,$amount,$name,$user,$symbol);};
    if($@)
    {
		my $error = $@;
		eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to sell_save",undef);};
      return $error;
    }
    # Add money from/to the portfolio
    eval {ExecSQL($dbuser,$dbpasswd, "update port_portfolio set cash = cash + ? where name=? and email=?",undef,$cash,$name,$user);};
    if($@)
    {
		my $error = $@;
		eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to sell_save",undef);};
      return $error;
    }
    # Remove the stock row if the user no longer owns any of this stock
    eval {ExecSQL($dbuser,$dbpasswd, "delete from port_stocksUser where name=? and email=? and symbol=? and amount = 0",undef,$name,$user,$symbol);};
    if($@)
    {
		my $error = $@;
		eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to sell_save",undef);};
      return $error;
    }else{		
		eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to sell_save",undef);};
		eval{ExecSQL($dbuser,$dbpasswd,"COMMIT",undef);};
		return $@ if $@;
	}
  }
  else
  {
    return "There was a problem when buying/selling $symbol. Please try again";
  }


  return;
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
  eval {
	  ExecSQL($dbuser,$dbpasswd,"SAVEPOINT transfer_save",undef);
	  @col=ExecSQL($dbuser,$dbpasswd, "select count(*) from port_portfolio where email=? and name in (?,?)","COL",$user,$nameMinus,$namePlus);};
  if($@ or $col[0]<2)
  {
    return "There was a problem when transfering money. Please try again";
  }

  # Deduct money from one portfolio (will return with error if insufficient funds)
  eval {ExecSQL($dbuser,$dbpasswd, "update port_portfolio set cash = cash - ? where name=? and email=?",undef,$cash,$nameMinus,$user);};
  if($@)
  {
	eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to transfer_save",undef);};
    return "There was a problem when transfering money. Please try again";
  }

  # Add money to the other portfolio
  eval {ExecSQL($dbuser,$dbpasswd, "update port_portfolio set cash = cash + ? where name=? and email=?",undef,$cash,$namePlus,$user);};
  if($@)
  {
	eval{ExecSQL($dbuser,$dbpasswd,"ROLLBACK to transfer_save",undef);};
    return "There was a problem when transfering money. Please try again";
  }else{
	eval{ExecSQL($dbuser,$dbpasswd,"COMMIT",undef);};
	return $@ if $@;
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
  $volume =~ s/[_,-]//g;  # remove commas from volume

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
    @cash = ExecSQL($dbuser, $dbpasswd, "select cash from port_portfolio where email = ? and name = ?", "ROW", $user, $portName);
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
    my ($beta,$err) = getBeta($stockSymbol);
    if (defined $err)
    {
      return (undef,undef,undef,undef,$@);
    }

    # Push the stock's beta into the stockRow
    push(@$_, $beta);

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

sub getStockValues
{
  my ($symbol) = @_;
  my @return;

  # Get the most recent price of the stock
  my $stockPrice;
  eval
  {
    ($stockPrice) = ExecSQL($dbuser, $dbpasswd, "select close from (select close, timestamp from port_stocksDaily where symbol = ?) sd1 natural join (select max(timestamp) timestamp from port_stocksDaily where symbol = ?) sd2", "COL",$symbol, $symbol);
  };
  if ($@)
  { 
    return (undef,undef,undef$@);
  }
  # Push the stock's price into the return value
  push(@return, sprintf('%3.2f',$stockPrice));

  # Get the stock's coefficient of variation
  my $coeffVariation;
  eval
  {
    ($coeffVariation) = ExecSQL($dbuser, $dbpasswd, "select stddev(close)/avg(close) from port_stocksDaily where symbol=?","ROW",$symbol);
  };
  if ($@)
  { 
    return (undef,undef,undef,$@);
  }
  # Push the stock's coefficient of variation into the return value
  push(@return, sprintf('%3.4f',$coeffVariation));

  # Get the stock's beta
  my ($beta,$err) = getBeta($symbol);
  if (defined $err)
  {
    return (undef,undef,undef,$err);
  }
  # Push the stock's coefficient of variation into the return value
  push(@return, sprintf('%3.4f',$beta));

  #Push a undef value for the error
  push(@return, undef);

  return @return;
}

sub getStockPredictions
{
  my ($symbol, $steps) = @_;
  my $out = `time_series_symbol_project.pl $symbol $steps AR 16 2>&1`;

  return $out;
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
    <div id="stockHistoryGraphDiv">
      <canvas id="stockHistoryGraph" width="400" height="400"></canvas>
    </div>
HTML

  # now we need a graph plotting time for these dates as well as their price
  return $history;
}

sub getAutoTrade
{
	my ($user, $stock) = @_;
	
	my $AutoTrade = << "HTML";
    <p>Insert a date range before 2006.</p>
    <form id="autoTradeForm" action="portfolio.pl" method="get">
      <input type="hidden" name="act" value="autotrade">
      <input type="hidden" name="stockName" value=$stock>
      <div class="row">
        <div class="large-4 columns">
          <label>Start Date
            <input class="datePicker" type="text" name="startDate" value="$startDate">
          </label>
        </div>
        <div class="large-4 columns">
          <label>End Date
            <input class="datePicker" type="text" name="endDate" value="$endDate">
          </label>
        </div>
        <div class="large-4 columns">
			<label>Starting Cash
				<input type="text" name="startCash" value="$startCash">
			</label>
		</div>
      </div>
	  <div class="row">
	  	<div class="large-4 columns">
			<label>Trading Cost per Day
				<input type="text" name="tradeCost" value="$tradeCost">
			</label>
		</div>
	  </div>
      <div class="row">
        <input type="submit" class="button" value="Update">
      </div>
    </form>
	<p><b>Invested:</b> $startCash</p>
	<p><b>Days:</b> $daysTraded</p>
	<p><b>Total:</b> $total</p>
  <p style="padding-left:20px;"><b>ROI:</b> $roi%</p>
  <p style="padding-left:20px;"><b>ROI-Annual:</b> $roiAnnual%</p>
	<p><b>Total after trade costs:</b> $totalAfterTradingCost
  <p style="padding-left:20px;"><b>ROI:</b> $roiAtCost%</p>
  <p style="padding-left:20px;"><b>ROI-Annual:</b> $roiAnnualAtCost%</p>

HTML

	return $AutoTrade;
}

sub getHistory
{
  my ($stock, $start, $end) = @_;
  # Parse date strings and convert to timestamp
  # Then query database for proper times and stuff
  my ($startMonth, $startDay, $startYear) = split(/\//, $start);
  my ($endMonth, $endDay, $endYear) = split(/\//, $end);

  # Beginning of first day
  $startTimestamp = timelocal(0, 1, 0, $startDay, $startMonth-1, $startYear);
  # End of last day
  $endTimestamp = timelocal(0, 59, 23, $endDay, $endMonth-1, $endYear);

  # Now basically query the database for close dates for apple between these timestamps
  my @colClose;
  my @colTimestamp;
  eval{
    @colClose = ExecSQL($dbuser, $dbpasswd, "select close from port_stocksDaily where timestamp>=? and timestamp<=? and symbol=? order by timestamp", "COL", $startTimestamp, $endTimestamp, $stock);
    @colTimestamp = ExecSQL($dbuser, $dbpasswd, "select timestamp from port_stocksDaily where timestamp>? and timestamp<? and symbol=? order by timestamp", "COL", $startTimestamp, $endTimestamp, $stock);
  };

  return (@colClose, @colTimestamp);
}

sub autoTrade
{
	my ($stockName, $startDate, $endDate, $startCash, $tradeCost) = @_;

  	my ($startMonth, $startDay, $startYear) = split(/\//, $startDate);
  	my ($endMonth, $endDay, $endYear) = split(/\//, $endDate);

  	# Beginning of first day
  	$startTimestamp = timelocal(0, 0, 0, $startDay, $startMonth-1, $startYear);
  	# End of last day
  	$endTimestamp = timelocal(0, 59, 23, $endDay, $endMonth-1, $endYear);
	
	my @stockRows;
	eval{@stockRows = ExecSQL($dbuser, $dbpasswd, "select close from port_stocksDaily where timestamp>? and timestamp<? and symbol=?","COL",$startTimestamp,$endTimestamp, $stockName);};

	return shannonRatchet(\@stockRows);

}

sub shannonRatchet
{
	my ($stockRowsScalar) = @_;
	my @stockRows = @$stockRowsScalar;

	
	my ($initialcash,$tradecost) = ($startCash,$tradeCost);
	
	
	my $lastcash=$initialcash;
	my $laststock=0;
	my $lasttotal=$lastcash;
	my $lasttotalaftertradecost=$lasttotal;
	
	my $cash=0;
	my $stock=0;
	my $total=0;
	my $totalaftertradecost=0;
	
	my $day=0;
	
	my $currenttotal;
	my $fractioncash;
	my $thistradecost;
	my $redistcash;
	my $fractionstock;
	
	my $roi;
	my $roi_annual;
	my $roi_at;
	my $roi_at_annual;	
	
	foreach my $stockprice (@stockRows) { 
	  chomp;
	
	  $currenttotal=$lastcash+$laststock*$stockprice;
	  if ($currenttotal<=0) {
	   return;
	  }
	  
	  $fractioncash=$lastcash/$currenttotal;
	  $fractionstock=($laststock*$stockprice)/$currenttotal;
	  $thistradecost=0;
	  if ($fractioncash >= 0.5 ) {
	    $redistcash=($fractioncash-0.5)*$currenttotal;
	    if ($redistcash>0) {
	      $cash=$lastcash-$redistcash;
	      $stock=$laststock+$redistcash/$stockprice;
	      $thistradecost=$tradecost;
	    } else {
	      $cash=$lastcash;
	      $stock=$laststock;
	    } 
	  }  else {
	    $redistcash=($fractionstock-0.5)*$currenttotal;
	    if ($redistcash>0) {
	      $cash=$lastcash+$redistcash;
	      $stock=$laststock-$redistcash/$stockprice;
	      $thistradecost=$tradecost;
	    }
	  }
	  
	  $total=$cash+$stock*$stockprice;
	  $totalaftertradecost=($lasttotalaftertradecost-$lasttotal) - $thistradecost + $total; 
	  $lastcash=$cash;
	  $laststock=$stock;
	  $lasttotal=$total;
	  $lasttotalaftertradecost=$totalaftertradecost;
	
	  $day++;
	  
	
	}
	
	
	$roi = 100.0*($lasttotal-$initialcash)/$initialcash;
	$roi_annual = $roi/($day/365.0);
	
	$roi_at = 100.0*($lasttotalaftertradecost-$initialcash)/$initialcash;
	$roi_at_annual = $roi_at/($day/365.0);
	
	
	return ($total, $roi, $roi_annual,$lasttotalaftertradecost,$roi_at,$roi_at_annual,$day);

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
# Get the stocks beta
#
sub getBeta
{

  # Get Input
  my ($stockSymbol) = @_;

  # Initialize variables
  my ($mean_f1,$std_f1, $mean_f2, $std_f2);
  my $covar;
  my $beta;
  my $count;
  my $entries;

  # Find out if the beta for this stock has a cached value for the stock data currently available
  eval
  {
    ($count) = ExecSQL($dbuser,$dbpasswd,"select count(*) from port_stocksDaily where symbol=?","COL",$stockSymbol);
    ($entries, $beta) = ExecSQL($dbuser,$dbpasswd,"select entries, beta from port_betaCache where symbol=?","ROW",$stockSymbol);
  };
  if ($@)
  {
    return (undef,$@);
  }
  # If the beta value hasn't been cached since new data was added, calculate it
  if(!(defined $entries) or $count != $entries)
  {
    eval
    {
      ($mean_f1,$std_f1, $mean_f2, $std_f2) = ExecSQL($dbuser,$dbpasswd,"select avg(s1.close),stddev(s1.close), avg(s2.close), stddev(s2.close) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp = s2.timestamp where s1.symbol=?","ROW",$stockSymbol);
    };
    if ($@)
    { 
      return (undef,$@);
    }

    if (!(defined $std_f1) or !(defined $std_f2) or $std_f1 == 0 or $std_f2 == 0)
    {
      $beta = 'NODAT';
    }
    else
    {
      eval
      {
        ($covar) = ExecSQL($dbuser,$dbpasswd,"select avg( (s1.close - ?)*(s2.close - ?) ) from port_stocksDaily s1 join port_stocksDaily s2 on s1.timestamp=s2.timestamp where s1.symbol=?", "COL",$mean_f1,$mean_f2,$stockSymbol);
      };
      if ($@)
      { 
        return (undef,$@);
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
        return (undef,$@);
      }
    }
  }

  # Return the beta value
  if ($beta eq 'NODAT')
  {
    return ($beta, undef)
  }
  else
  {
    return (sprintf('%3.4f',$beta), undef)
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
  $ENV{PATH} = $ENV{PATH}.":/home/cwo258/www/Portfolio";
  $ENV{PATH} = $ENV{PATH}.":/home/dbe261/www/port";
  $ENV{PATH} = $ENV{PATH}.":/home/maa935/www/portfolio";

  $ENV{PORTF_DBMS} = "oracle";
  $ENV{PORTF_DB} = "cs339";
  $ENV{PORTF_DBUSER} = "dbe261";
  $ENV{PORTF_DBPASS} = "guest";

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

