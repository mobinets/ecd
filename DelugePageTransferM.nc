// $Id: DelugePageTransferM.nc,v 1.31 2005/08/17 23:36:34 jwhui Exp $

/*									tab:2
 *
 *
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 */

/**
 * @author Jonathan Hui <jwhui@cs.berkeley.edu>
 */
#include <math.h>

#define ELECTION_PERIOD 272
#define CONTENTION_PERIOD 272
#define PKT_TIME   22   // 15ms ,,  21
#define N_FACTOR    11

module DelugePageTransferM {
  provides {
    interface StdControl;
    interface DelugePageTransfer as PageTransfer;
  }
  uses {
    interface BitVecUtils;
    interface DelugeDataRead as DataRead;
    interface DelugeDataWrite as DataWrite;
    interface DelugeStats;
    interface Leds;
    interface Random;
    interface ReceiveMsg as ReceiveDataMsg;
    interface ReceiveMsg as ReceiveReqMsg;
    interface SendMsg as SendDataMsg;
    interface SendMsg as SendReqMsg;
    interface SharedMsgBuf;
    interface Timer;
    
    interface Timer as ReqTimer;
    interface Timer as PrioTimer;
    interface SystemTime;
    // Wei
#ifndef PLATFORM_PC
    interface Bcast;
#endif
  }
}

implementation {

  // send/receive page buffers, and state variables for buffers
  uint8_t  pktsToSend[DELUGE_PKT_BITVEC_SIZE];    // bit vec of packets to send
  uint8_t  pktsToReceive[DELUGE_PKT_BITVEC_SIZE]; // bit vec of packets to receive

  DelugeDataMsg rxQueue[DELUGE_QSIZE];
  uint8_t head, size;

  // state variables
  uint8_t  state;
  imgnum_t workingImgNum;
  pgnum_t  workingPgNum;
  uint16_t nodeAddr;
  uint8_t  remainingAttempts;
  bool     suppressReq;
  uint8_t  imgToSend;
  uint8_t  pageToSend;

  //
  bool waitReqLock=FALSE;
  uint16_t newMetric=0; // the new metric employed by our protocol
  uint32_t last_data_time = 0;
  uint8_t  last_data_pendPktNum = 0;
  uint8_t  last_data_totalPktNum = 0;
  uint16_t last_data_source = 0;
  uint8_t  last_data_metric = 0;

  
  uint8_t  myTotalPktNum = 0;
  bool shouldSend = FALSE;
  uint8_t  myPktsToSend = 0; 
  uint8_t  myMetric = 0;

  // how to count distinct requesters??
  uint16_t requesters[25]; // please modify this correspondingly
  uint8_t  requested_pgNum[25];
  uint8_t  reqNum = 0;
  uint8_t  reqImgNum = 0xff;
  uint8_t  reqPgNum  = 0xff;

#include "prr_pow2.h"
  
  enum {
    S_DISABLED,
    S_IDLE,     
    S_TX_LOCKING,
    S_SENDING,
    S_RX_LOCKING,
    S_RECEIVING,
  };

  bool dwIsRequestPkt(uint8_t *requestedPkts, uint8_t pkt) {
    return (requestedPkts[pkt>>3]) & (0x1<<(pkt&0x7));
  }
  
  void printReqMsg(uint8_t *requestedPkts) {
    uint8_t j;
    char requestInfo[DELUGE_PKTS_PER_PAGE+1];
    requestInfo[DELUGE_PKTS_PER_PAGE] = 0;

    for (j = 0; j < DELUGE_PKTS_PER_PAGE; ++j)
      if (dwIsRequestPkt(requestedPkts, j))
        requestInfo[j] = '1';
      else 
        requestInfo[j] = '0';

    dbg(DBG_USR1, "DELUGE: [%s]\n", requestInfo);
  }

  void clear_requesters()
  {
    memset(requesters, 0xff, 25*sizeof(uint16_t));
    reqNum=0;
    reqPgNum=0xff;
    reqImgNum=0xff;
  }


  void add_requester(DelugeReqMsg* reqMsg)
  {
    uint8_t i=0;

    if (reqNum==25) return; // donot add

    if (reqPgNum != 0xff) { // see it further
      if (reqMsg->pgNum<reqPgNum) {
        // clear and add it
        clear_requesters();
      }
      else if (reqMsg->pgNum==reqPgNum) {
        // add it
      }
      else if (reqMsg->pgNum>reqPgNum) {
        // ignore it -- donot add
        return;
      }
    }
    
    for (i=0; i<reqNum; i++) {
      if (requesters[i]==reqMsg->sourceAddr) 
        return; // already in the set
    }
    requesters[reqNum] = reqMsg->sourceAddr;
    requested_pgNum[reqNum] = reqMsg->pgNum; // we can also save the requested vectors
    reqPgNum = reqMsg->pgNum;
    // DW: fixme
    reqImgNum = reqMsg->imgNum;
    
    reqNum++;
  }


  uint8_t compute_metric()
  {
    //
    float effective_nb=0;
    uint8_t i=0;

    for (i=0; i<reqNum; i++) {
      effective_nb += 1.0 * pktrr[TOS_LOCAL_ADDRESS][requesters[i]]/255.0;
    }

    if (effective_nb>N_FACTOR) effective_nb=N_FACTOR;
    
    return (uint8_t)effective_nb;
  }

  uint8_t compute_real_metric(uint8_t maxnb)
  {
    float effective_nb=0;
    uint8_t i=0;

    for (i=0; i<reqNum; i++) {
      effective_nb += 1.0 * pktrr[TOS_LOCAL_ADDRESS][requesters[i]]/255.0;
    }

    //pow(pktrr[TOS_LOCAL_ADDRESS][requesters[i]]/255.0, 3);
    
    if (effective_nb>N_FACTOR) effective_nb=N_FACTOR;

    //dbg(DBG_USR1, "eff1 %f\n", effective_nb);
    effective_nb = effective_nb*255.0/maxnb;
    //dbg(DBG_USR1, "eff2 %f\n", effective_nb);
    
    return (uint8_t)effective_nb;
  }

  void changeState(uint8_t newState) {
    
    if ((newState == S_DISABLED || newState == S_IDLE)
	&& (state == S_SENDING || state == S_RECEIVING))
      call SharedMsgBuf.unlock();

    if (newState==S_IDLE) 
    {
      waitReqLock=TRUE; 
      memset(pktsToSend, 0, DELUGE_PKT_BITVEC_SIZE);
      clear_requesters();
    }

    state = newState;
    
  }

  bool others_transmitting() {
    uint32_t currentTime = call SystemTime.getCurrentTimeMillis();
//    if ( (myPktsToSend<last_data_totalPktNum 
//          || (myPktsToSend==last_data_totalPktNum && last_data_source<TOS_LOCAL_ADDRESS) )
//         && currentTime-last_data_time<=100 && last_data_pendPktNum > 1)  
    if (currentTime-last_data_time<=75 && last_data_metric>=myMetric && last_data_pendPktNum>=8)
    {
      return TRUE;
    }
    return FALSE;
  }

  
  command result_t StdControl.init() {
    changeState(S_DISABLED);
    workingImgNum = DELUGE_INVALID_IMGNUM;
    workingPgNum = DELUGE_INVALID_PGNUM;
//DW
    memset(pktrr, 255, 25*25);
    
    return SUCCESS;
  }

  command result_t StdControl.start() {
    changeState(S_IDLE);
    call Random.init();
#ifndef PLATFORM_PC
    call Bcast.startBcast();
#endif
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    changeState(S_DISABLED);
    return SUCCESS;
  }

  command result_t PageTransfer.setWorkingPage(imgnum_t imgNum, pgnum_t pgNum) {
    workingImgNum = imgNum;
    workingPgNum = pgNum;
    memset(pktsToReceive, 0xff, DELUGE_PKT_BITVEC_SIZE);
    return SUCCESS;
  }

  command bool PageTransfer.isTransferring() {
    return (state != S_IDLE && state != S_DISABLED);
  }

  void startReqTimer(bool first) {
    uint32_t delay;
    if (first)
      delay = DELUGE_MIN_DELAY + (call Random.rand() % DELUGE_MAX_REQ_DELAY);//16+[0,256)
    else
      delay = DELUGE_NACK_TIMEOUT + (call Random.rand() % DELUGE_NACK_TIMEOUT);//128+[128,128)
    call Timer.start(TIMER_ONE_SHOT, delay);
  }

  command result_t PageTransfer.dataAvailable(uint16_t sourceAddr, imgnum_t imgNum) {

    if ( state == S_IDLE && workingImgNum == imgNum ) {
      // currently idle, so request data from source
      changeState(S_RX_LOCKING);
      nodeAddr = sourceAddr;
      remainingAttempts = DELUGE_MAX_NUM_REQ_TRIES;
      suppressReq = FALSE;
      
      // randomize request to prevent collision
      startReqTimer(TRUE);
    }

    return SUCCESS;

  }

  block_addr_t calcOffset(pgnum_t pgNum, uint8_t pktNum) {
    return (block_addr_t)pgNum*(block_addr_t)DELUGE_BYTES_PER_PAGE
      + (uint16_t)pktNum*(uint16_t)DELUGE_PKT_PAYLOAD_SIZE
      + DELUGE_METADATA_SIZE;
  }
  
  void setupReqMsg() {

    TOS_MsgPtr pMsgBuf = call SharedMsgBuf.getMsgBuf();
    DelugeReqMsg* pReqMsg = (DelugeReqMsg*)(pMsgBuf->data);
    uint16_t reqAddr;
    
    if ( state == S_RX_LOCKING ) {
      if ( call SharedMsgBuf.isLocked() )
	    return;
      call SharedMsgBuf.lock();
      changeState(S_RECEIVING); // only when buffer is free, we enter into the receiving state
      pReqMsg->dest = (nodeAddr != TOS_UART_ADDR) ? nodeAddr: TOS_UART_ADDR;

      reqAddr = (nodeAddr != TOS_UART_ADDR) ? 0xffff: TOS_UART_ADDR;

      pReqMsg->sourceAddr = TOS_LOCAL_ADDRESS;
      pReqMsg->imgNum = workingImgNum;
      pReqMsg->vNum = call DelugeStats.getVNum(workingImgNum);
      pReqMsg->pgNum = workingPgNum;
    }

    if (state != S_RECEIVING)
      return;

    // suppress request
    if ( suppressReq ) {
      startReqTimer(FALSE);
      suppressReq = FALSE;
    }
    
    // tried too many times, give up
    else if ( remainingAttempts == 0 ) {
      changeState(S_IDLE);
    }

    // send req message
    else {
      memcpy(pReqMsg->requestedPkts, pktsToReceive, DELUGE_PKT_BITVEC_SIZE);
      if (call SendReqMsg.send(reqAddr, sizeof(DelugeReqMsg), pMsgBuf) == FAIL) {
	startReqTimer(FALSE);
      } else {
#ifdef PLATFORM_PC
        char strTime[20];
        printTime(strTime, sizeof strTime);
        //pr("DELUGE: RECV_DONE %d at %s\n", pgNum, strTime);
        pr("ReqMsg %d: %d -> %d (%s)\n", pReqMsg->pgNum, 
                    TOS_LOCAL_ADDRESS, pReqMsg->dest, strTime);
        printReqMsg(pReqMsg->requestedPkts);
#else
        pr("ReqMsg: %d -> %d\n", TOS_LOCAL_ADDRESS, pReqMsg->dest);
#endif
        
      }
    }

  }

  void writeData() {
    if( call DataWrite.write(workingImgNum, calcOffset(rxQueue[head].pgNum, rxQueue[head].pktNum),
			     rxQueue[head].data, DELUGE_PKT_PAYLOAD_SIZE) == FAIL )
      size = 0;
  }

  void suppressMsgs(imgnum_t imgNum, pgnum_t pgNum) {
    if (state == S_SENDING || state == S_TX_LOCKING) 
    {
      if (imgNum < imgToSend
	  || (imgNum == imgToSend
	      && pgNum < pageToSend)) // I should take off the responsibility because someone else is currently transmitting 
	  { // if a low page # is currently transmitting
	    changeState(S_IDLE);
	     memset(pktsToSend, 0x0, DELUGE_PKT_BITVEC_SIZE);
      }
    }
    else if (state == S_RECEIVING || state == S_RX_LOCKING) 
    {
      if (imgNum < workingImgNum
	  || (imgNum == workingImgNum
	      && pgNum <= workingPgNum)) 
	  { // if a similar request or request for lower page # is overheard
	    // suppress next request since similar request has been overheard
	    suppressReq = TRUE;
	    //DW: add this
	    if (imgNum==workingImgNum && pgNum==workingPgNum) {
	      //DW see last_data_time
	      uint32_t currentTime = 0;
          currentTime = call SystemTime.getCurrentTimeMillis();

          if (currentTime - last_data_time<=100/*ms*/) {
            suppressReq = TRUE; // suppress because someone is currently transmitting data (perhaps serve for me!!)
          }
          else { 
            suppressReq = FALSE; // if the same (img,pg) respond and let the sender know
            //dbg(DBG_USR1, "not suppressed in this protocol\n");
          }
	    }
      }
    }
  }

  event TOS_MsgPtr ReceiveDataMsg.receive(TOS_MsgPtr pMsg) {

    DelugeDataMsg* rxDataMsg = (DelugeDataMsg*)pMsg->data;
    
    //PKT_LOSS(pMsg);

    if ( state == S_DISABLED
	 || rxDataMsg->imgNum >= DELUGE_NUM_IMAGES )
      return pMsg;

    //DW
    //dbg(DBG_USR1, "DELUGE: Received DATA_MSG(vNum=%d,imgNum=%d,pgNum=%d,pktNum=%d)\n",
	//rxDataMsg->vNum, rxDataMsg->imgNum, rxDataMsg->pgNum, rxDataMsg->pktNum);

	//DW receive or overhear the data packet
	last_data_time = call SystemTime.getCurrentTimeMillis();
	last_data_pendPktNum = rxDataMsg->pendPktNum;
	last_data_totalPktNum = rxDataMsg->totalPktNum;
	last_data_source = rxDataMsg->sourceAddr;
	last_data_metric = rxDataMsg->metric;

    // check if need to suppress req or data messages
    suppressMsgs(rxDataMsg->imgNum, rxDataMsg->pgNum);

    if (rxDataMsg->pendPktNum<=10) {
    //  dbg(DBG_USR1, "s=%d(%d %d %d)\n", state, imgToSend, pageToSend, rxDataMsg->sourceAddr);
    }

    if (last_data_totalPktNum==DELUGE_PKTS_PER_PAGE) {
    //  dbg(DBG_USR1, "receivedmsg from %d s=%d\n", last_data_source, state);
    }

    // DW: taken from suppressMsgs: when just before sending (idle) clear it also
    if (state==S_IDLE || state == S_SENDING || state == S_TX_LOCKING) {
      if ( (rxDataMsg->imgNum == imgToSend
	      && rxDataMsg->pgNum == pageToSend)) { // I should take off the responsibility because someone else is currently transmitting 
	    // clear bits in pktsToSend and change to IDLE when pktsToSend is empty
        uint16_t nextPkt;
/*
// debug
 if (rxDataMsg->pendPktNum<=10) {
   dbg(DBG_USR1, "%d: %d %d %d %d \n", others_transmitting(),
       myPktsToSend, last_data_totalPktNum, last_data_source, last_data_pendPktNum);
 }
 */
        //if it fully covers me
        if (others_transmitting()) {
          changeState(S_IDLE); // clear all
          //dbg("clear all\n");
          return pMsg;
        }
        /*
        else {
        
          BITVEC_CLEAR(pktsToSend, rxDataMsg->pktNum);
          //dbg(DBG_USR1, "clear one pkt %d because hear %d\n", rxDataMsg->pktNum, rxDataMsg->sourceAddr);

          //memset(pktsToSend, 0, DELUGE_PKT_BITVEC_SIZE);
          //changeState(S_IDLE);
        
          if (!call BitVecUtils.indexOf(&nextPkt, rxDataMsg->pktNum, pktsToSend, DELUGE_PKTS_PER_PAGE)) {    
            changeState(S_IDLE);
            return pMsg;
          }

          if ( (myPktsToSend<last_data_totalPktNum 
                || (myPktsToSend==last_data_totalPktNum && last_data_source<TOS_LOCAL_ADDRESS) )
                && last_data_pendPktNum > 1)  { 
            // we should let others send
            uint16_t wait_time = (last_data_pendPktNum<=10)?PKT_TIME*last_data_pendPktNum+ELECTION_PERIOD:PKT_TIME*last_data_pendPktNum/2;
            waitReqLock = TRUE;
            call ReqTimer.start(TIMER_ONE_SHOT, wait_time);
            dbg(DBG_USR1, "EDELUGE: overhear wait %d (%d,%d)\n", wait_time, last_data_source, last_data_pendPktNum);
          }
        } 
        */
      }
    }

    if ( rxDataMsg->vNum == call DelugeStats.getVNum(rxDataMsg->imgNum)
	 && rxDataMsg->imgNum == workingImgNum
	 && rxDataMsg->pgNum == workingPgNum
	 && BITVEC_GET(pktsToReceive, rxDataMsg->pktNum)
	 && size < DELUGE_QSIZE ) {
      // got a packet we need
      call Leds.set(rxDataMsg->pktNum);

      //DW
      //dbg(DBG_USR1, "DELUGE: SAVING(pgNum=%d,pktNum=%d)\n", 
	  //rxDataMsg->pgNum, rxDataMsg->pktNum);
      
      // copy data
      memcpy(&rxQueue[head^size], rxDataMsg, sizeof(DelugeDataMsg));
      if ( ++size == 1 ) 
	    writeData();
    }

    return pMsg;

  }

  void setupDataMsg() {

    TOS_MsgPtr pMsgBuf = call SharedMsgBuf.getMsgBuf();
    DelugeDataMsg* pDataMsg = (DelugeDataMsg*)(pMsgBuf->data);

    uint16_t nextPkt;

    if (state != S_SENDING && state != S_TX_LOCKING)
      return;
    
    signal PageTransfer.suppressMsgs(imgToSend);

    if ( state == S_TX_LOCKING ) {
      uint16_t result;
      // remaining in the TX_LOCKING state
      if ( call SharedMsgBuf.isLocked() || waitReqLock)
	    return;
      call SharedMsgBuf.lock();
      changeState(S_SENDING);
      pDataMsg->vNum = call DelugeStats.getVNum(imgToSend);
      pDataMsg->imgNum = imgToSend;
      pDataMsg->pgNum = pageToSend;
      pDataMsg->pktNum = 0;
      //      myTotalPktNum;

      // return value indicate sucess or failure.
      call BitVecUtils.countOnes(&result, pktsToSend, DELUGE_PKTS_PER_PAGE);
      myTotalPktNum = result;
      pDataMsg->totalPktNum = myTotalPktNum;
      pDataMsg->pendPktNum = myTotalPktNum;

      // consistency
      myPktsToSend = myTotalPktNum;
      myMetric  =  compute_real_metric(N_FACTOR);
    }

    if (!call BitVecUtils.indexOf(&nextPkt, pDataMsg->pktNum, 
				  pktsToSend, DELUGE_PKTS_PER_PAGE)) {
      // no more packets to send
      dbg(DBG_USR1, "DELUGE: SEND_DONE\n");
      // do we need to reset the timer??
      changeState(S_IDLE);
    }
    else {
      uint16_t result;
      pDataMsg->pktNum = nextPkt;
      // return value indicate sucess or failure.
      call BitVecUtils.countOnes(&result, pktsToSend, DELUGE_PKTS_PER_PAGE);
      pDataMsg->pendPktNum = result;
      pDataMsg->totalPktNum = myTotalPktNum;
      pDataMsg->sourceAddr = TOS_LOCAL_ADDRESS;
      pDataMsg->metric = compute_real_metric(N_FACTOR);
      if (call DataRead.read(imgToSend, calcOffset(pageToSend, nextPkt), 
			     pDataMsg->data, DELUGE_PKT_PAYLOAD_SIZE) == FAIL)
	call Timer.start(TIMER_ONE_SHOT, DELUGE_FAILED_SEND_DELAY);
    }

  }

  event result_t Timer.fired() {
    setupReqMsg();
    setupDataMsg();
    return SUCCESS;
  }

  event TOS_MsgPtr ReceiveReqMsg.receive(TOS_MsgPtr pMsg) {

    DelugeReqMsg *rxReqMsg = (DelugeReqMsg*)(pMsg->data);
    imgnum_t imgNum;
    pgnum_t pgNum;
    int i;

    //call Leds.yellowToggle();

    //dbg(DBG_USR1, "DELUGE: Received REQ_MSG(src=%d,dest=%d,vNum=%d,imgNum=%d,pgNum=%d,pkts=%x)\n",
	//rxReqMsg->sourceAddr, rxReqMsg->dest, rxReqMsg->vNum, rxReqMsg->imgNum, rxReqMsg->pgNum, rxReqMsg->requestedPkts[0]);

    if ( state == S_DISABLED
	 || rxReqMsg->imgNum >= DELUGE_NUM_IMAGES )
      return pMsg;

    imgNum = rxReqMsg->imgNum;
    pgNum = rxReqMsg->pgNum;
    
    // check if need to suppress req or data msgs
    suppressMsgs(imgNum, pgNum);

    
    if (rxReqMsg->vNum != call DelugeStats.getVNum(imgNum)
        || pgNum >= call DelugeStats.getNumPgsComplete(imgNum)) // pgNum: from 0 to NumPgs-1
    {
      return pMsg;
    }
    //DW: we must account for every valid req messge for sender selection
    else {
      //if (imgToSend==imgNum && pageToSend==pgNum) {
        add_requester(rxReqMsg);
      //} else {
      //  clear_requesters();
      //  add_requester(rxReqMsg->sourceAddr);
      //}
    }

    // if not for me, ignore request
    // DW: we must use it for sender selection
    /*
       if ( rxReqMsg->dest != TOS_LOCAL_ADDRESS
	 || rxReqMsg->vNum != call DelugeStats.getVNum(imgNum)
	 || pgNum >= call DelugeStats.getNumPgsComplete(imgNum) )
         return pMsg;
        */

    call Leds.redToggle();

    //ignore this
    if (state==S_SENDING) {
      uint16_t result;

      call BitVecUtils.countOnes(&result, rxReqMsg->requestedPkts, DELUGE_PKTS_PER_PAGE);
      if (result > 5) {
        dbg(DBG_USR1, "send return got from %d\n", rxReqMsg->sourceAddr);
        //printReqMsg(rxReqMsg->requestedPkts);
        return pMsg;
      }
    }

    //dbg(DBG_USR1, "receive request messages %d\n", state);

    if ( state == S_IDLE
	 || ( (state == S_SENDING || state == S_TX_LOCKING)
	      && imgNum == imgToSend
	      && pgNum == pageToSend ) ) 
	{ // even if not intended for me, I also take the responsibility
      // take union of packet bit vectors
      for ( i = 0; i < DELUGE_PKT_BITVEC_SIZE; i++ )
	    pktsToSend[i] |= rxReqMsg->requestedPkts[i];
    }

    if (rxReqMsg->dest == TOS_LOCAL_ADDRESS) {
      shouldSend = TRUE;
    }

    
    
    if ( state == S_IDLE ) { // receive the req for the first time
      // not currently sending, so start sending data
      //DW: wait for multiple NACKs to allow sender selection
      changeState(S_TX_LOCKING);
      imgToSend = reqImgNum;//imgNum;
      pageToSend = reqPgNum;//pgNum;
      nodeAddr = (rxReqMsg->sourceAddr != TOS_UART_ADDR) ? TOS_BCAST_ADDR : TOS_UART_ADDR;
      
      if (others_transmitting())  {
        changeState(S_IDLE);
        //dbg(DBG_USR1, "overhear others and wait...[my(%d)<%d(%d)]\n", myPktsToSend, last_data_source, last_data_totalPktNum);
      } else {
        waitReqLock = TRUE;
        call ReqTimer.start(TIMER_ONE_SHOT, ELECTION_PERIOD); // for collect multiple NACKs
      }
    }
    return pMsg;
  }

  event result_t ReqTimer.fired()
  {
    // set prio_interval
    uint16_t CWmax=CONTENTION_PERIOD;
    uint16_t N=N_FACTOR;
    uint16_t t=256;
    float delta = (CWmax-t)/(N-1);
    uint16_t prio_interval;

    uint8_t metric=0;

    if (!shouldSend && reqNum<=2) 
       {
         memset(pktsToSend, 0, DELUGE_PKT_BITVEC_SIZE);
         changeState(S_IDLE);
         return SUCCESS;
       }

    
    shouldSend = FALSE;
    
    metric=compute_metric();
    if (metric>N)  metric=N; // the maximum of metric

    prio_interval = (N-metric)*delta + call Random.rand()%t; // for simplicity
    
    if (prio_interval>CWmax) // guard it
      prio_interval = CWmax;

    dbg(DBG_USR1, "-->prio_interval=%d (reqNum=%d, metric=%d)\n", prio_interval, reqNum, metric);



    if (others_transmitting())  {
      changeState(S_IDLE);
      //dbg(DBG_USR1, "overhear others and wait...[my(%d)<%d(%d)]\n", myPktsToSend, last_data_source, last_data_totalPktNum);
      return SUCCESS;
    }    

#ifdef PLATFORM_PC
    { char strTime[20];
    printTime(strTime, sizeof strTime);
    //pr("DELUGE: RECV_DONE %d at %s\n", pgNum, strTime);
    dbg(DBG_USR1, "ReqTimer fired at %s\n", strTime);  }
#endif
    call PrioTimer.start(TIMER_ONE_SHOT, prio_interval);
    return SUCCESS;
  }

  event result_t PrioTimer.fired()
  {
    // if someone else is currently transmitting, we should not start the current transmission
    uint16_t result;

    call BitVecUtils.countOnes(&result, pktsToSend, DELUGE_PKTS_PER_PAGE);
    
    myPktsToSend=result;


    if (others_transmitting())  {
      changeState(S_IDLE);
      //dbg(DBG_USR1, "<--priotimer: wait: currentTime=%lu, last_data_time=%lu\n", currentTime, last_data_time);
      return SUCCESS;
    }

    // else
    dbg(DBG_USR1, "<--priotimer: start data transmission: reqNum=%d (%lu-%lu)\n", reqNum, currentTime, last_data_time);

#ifdef PLATFORM_PC
    { char strTime[20];
    printTime(strTime, sizeof strTime);
    //pr("DELUGE: RECV_DONE %d at %s\n", pgNum, strTime);
    dbg(DBG_USR1, "PrioTimer fired at %s\n", strTime);  }
#endif
    
    waitReqLock = FALSE;
    
    // clear_requesters()
    
    setupDataMsg();
    return SUCCESS;
  }

  event void DataRead.readDone(storage_result_t result) {

    TOS_MsgPtr pMsgBuf = call SharedMsgBuf.getMsgBuf();
    DelugeDataMsg* pDataMsg = (DelugeDataMsg*)(pMsgBuf->data);

    if (state != S_SENDING)
      return;

    if (result != STORAGE_OK) {
      changeState(S_IDLE);
      return;
    }

    if (call SendDataMsg.send(nodeAddr, sizeof(DelugeDataMsg), pMsgBuf) == FAIL) {
      call Timer.start(TIMER_ONE_SHOT, DELUGE_FAILED_SEND_DELAY);
    } else {
#ifdef PLATFORM_PC
      char strTime[20];
      printTime(strTime, sizeof strTime);
      //pr("DELUGE: RECV_DONE %d at %s\n", pgNum, strTime);
      pr("DataMsg %d %d: %d -> %d (%s) %d/%d (%d)\n", pDataMsg->pgNum, pDataMsg->pktNum,
        TOS_LOCAL_ADDRESS, nodeAddr, strTime, pDataMsg->pendPktNum, pDataMsg->totalPktNum, pDataMsg->metric);

      //printReqMsg(pktsToSend);
#else
      pr("DataMsg: %d -> %d\n", TOS_LOCAL_ADDRESS, nodeAddr);
#endif
    }

  }

  event void DataWrite.writeDone(storage_result_t result) {

    uint16_t tmp;

    // mark packet as received
    BITVEC_CLEAR(pktsToReceive, rxQueue[head].pktNum);
    head = (head+1)%DELUGE_QSIZE;
    size--;
    
    if (!call BitVecUtils.indexOf(&tmp, 0, pktsToReceive, DELUGE_PKTS_PER_PAGE)) {
      signal PageTransfer.receivedPage(workingImgNum, workingPgNum);
#ifndef PLATFORM_PC
      call Bcast.setTime();
#endif
      changeState(S_IDLE);
      size = 0;
    }
    else if ( size ) {
      writeData();
    }
    
  }

  event result_t SendReqMsg.sendDone(TOS_MsgPtr pMsg, result_t success) {

#ifndef PLATFORM_PC
      call Bcast.inc(DELUGE_TX_REQ);
#endif

    if (state != S_RECEIVING)
      return SUCCESS;
    
    remainingAttempts--;

    // start timeout timer in case request is not serviced
    startReqTimer(FALSE);
    return SUCCESS;

  }

  event result_t SendDataMsg.sendDone(TOS_MsgPtr pMsg, result_t success) {
    //uint16_t result;
          
    TOS_MsgPtr pMsgBuf = call SharedMsgBuf.getMsgBuf();
    DelugeDataMsg* pDataMsg = (DelugeDataMsg*)(pMsgBuf->data);
    BITVEC_CLEAR(pktsToSend, pDataMsg->pktNum);

    //call BitVecUtils.countOnes(&result, pktsToSend, DELUGE_PKTS_PER_PAGE);
    
    if (others_transmitting())  { // someone else is currently transmitting
      changeState(S_IDLE);
      //dbg(DBG_USR1, "overhear others and wait...[my(%d)<%d(%d)]\n", myPktsToSend, last_data_source, last_data_totalPktNum);
    } else {
      call Timer.start(TIMER_ONE_SHOT, 2);
    }
    //Wei
#ifndef PLATFORM_PC
    call Bcast.inc(DELUGE_TX_DATA);
#endif
    return SUCCESS;
  }
  
  event void SharedMsgBuf.bufFree() { 
    switch(state) {
    case S_TX_LOCKING: setupDataMsg(); break;
    case S_RX_LOCKING: setupReqMsg(); break;
    }
  }
  
  event void DataRead.verifyDone(storage_result_t result, bool isValid) {}
  event void DataWrite.eraseDone(storage_result_t result) {}
  event void DataWrite.commitDone(storage_result_t result) {}

}
