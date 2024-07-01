<?php require '../config.php';  ?>
<?php loadClass('Helper')->authPage(); ?>
<?php

//
// Includes
//
require $VEN_DIR . DIRECTORY_SEPARATOR . 'Mail' . DIRECTORY_SEPARATOR .'Mbox.php';
require $VEN_DIR . DIRECTORY_SEPARATOR . 'Mail' . DIRECTORY_SEPARATOR .'mimeDecode.php';
require $LIB_DIR . DIRECTORY_SEPARATOR . 'Mail.php';
require $LIB_DIR . DIRECTORY_SEPARATOR . 'Sort.php';

//
// Setup Sort/Order
//

// Sort/Order settings
$defaultSort	= array('sort' => 'date', 'order' => 'DESC');
$allowedSorts	= array('date', 'subject', 'x-original-to', 'from');
$allowedOrders	= array('ASC', 'DESC');
$GET_sortKeys	= array('sort' => 'sort', 'order' => 'order');

// Get sort/order
$MySort = new \devilbox\Sort($defaultSort, $allowedSorts, $allowedOrders, $GET_sortKeys);
$sort = $MySort->getSort();
$order = $MySort->getOrder();

$body = null;
if (isset($_GET['mail-id']) && is_numeric($_GET['mail-id'])) {
    $messageNumber = $_GET['mail-id'];
    $MyMbox = new \devilbox\Mail('/var/mail/devilbox');
    $message = $MyMbox->getMessage($messageNumber-1);
    $structure = $message['decoded'];

    if (isset($structure->body)) {
		$body = $structure->body;
	}
	elseif(isset($structure->parts[1]->body)) {
		$body = $structure->parts[1]->body;
	}
	elseif(isset($structure->parts[0]->body)) {
		$body = $structure->parts[0]->body;
	}
}
?>
<?= $body ?: 'No valid body found' ?>
