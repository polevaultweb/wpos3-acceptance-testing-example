<?php
$I = new AcceptanceTester( $scenario );

// Login to wp-admin
$I->loginAsAdmin();

// Navigate to the Media Library
$I->amOnPage( '/wp-admin/media-new.php' );
$I->waitForText( 'Upload New Media' );

// Add new file
$I->attachFile( 'input[type="file"]', 'team.jpg' );

// Wait for upload
$I->waitForElement( '.edit-attachment', 20 );
$I->seeElement( '.edit-attachment' );
$I->click( '.edit-attachment' );

// Navigate to the Edit Media window
$I->executeInSelenium( function ( \Facebook\WebDriver\Remote\RemoteWebDriver $webdriver ) {
	$handles     = $webdriver->getWindowHandles();
	$last_window = end( $handles );
	$webdriver->switchTo()->window( $last_window );
} );
$I->waitForText( 'Edit Media' );

// Check URL is an S3 one
$url  = $I->grabValueFrom( 'attachment_url' );
$this->assertContains( 'amazonaws.com', $url );

// Parse the URL
$url       = explode( '.com/', $url );
$url_parts = explode( '/', $url[1] );

$bucket = array_shift( $url_parts );
$key = implode( '/', $url_parts );

// Check attachment has been offloaded to Amazon S3
$I->setBucket( $bucket )->seeFile( $key );

