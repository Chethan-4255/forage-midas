package com.jpmc.midascore.service;

import com.jpmc.midascore.entity.TransactionRecord;
import com.jpmc.midascore.entity.UserRecord;
import com.jpmc.midascore.foundation.Incentive;
import com.jpmc.midascore.foundation.Transaction;
import com.jpmc.midascore.repository.TransactionRecordRepository;
import com.jpmc.midascore.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.web.client.RestTemplate;

@Service
public class TransactionService {

    private static final Logger log = LoggerFactory.getLogger(TransactionService.class);

    private final UserRepository userRepository;
    private final TransactionRecordRepository transactionRecordRepository;
    private final RestTemplate restTemplate;

    public TransactionService(UserRepository userRepository,
                              TransactionRecordRepository transactionRecordRepository,
                              RestTemplateBuilder restTemplateBuilder) {
        this.userRepository = userRepository;
        this.transactionRecordRepository = transactionRecordRepository;
        this.restTemplate = restTemplateBuilder.build();
    }

    @Transactional
    public void process(Transaction transaction) {
        if (transaction == null) {
            return;
        }
        long senderId = transaction.getSenderId();
        long recipientId = transaction.getRecipientId();
        float amount = transaction.getAmount();

        if (amount <= 0) {
            log.debug("Discarding transaction with non-positive amount: {}", amount);
            return;
        }

        UserRecord sender = userRepository.findById(senderId);
        UserRecord recipient = userRepository.findById(recipientId);

        if (sender == null || recipient == null) {
            log.debug("Discarding transaction due to invalid user ids: senderId={}, recipientId={}", senderId, recipientId);
            return;
        }

        if (sender.getBalance() < amount) {
            log.debug("Discarding transaction due to insufficient funds: senderId={}, balance={}, amount={}", senderId, sender.getBalance(), amount);
            return;
        }

        // Call incentives API
        float incentiveAmount = 0.0f;
        try {
            Incentive incentive = restTemplate.postForObject("http://localhost:8080/incentive", transaction, Incentive.class);
            if (incentive != null) {
                incentiveAmount = Math.max(0.0f, incentive.getAmount());
            }
        } catch (Exception e) {
            log.warn("Failed to retrieve incentive from API: {}", e.getMessage());
        }

        // Apply balance updates: incentive boosts recipient only
        sender.setBalance(sender.getBalance() - amount);
        recipient.setBalance(recipient.getBalance() + amount + incentiveAmount);

        userRepository.save(sender);
        userRepository.save(recipient);

        // Record transaction with incentive
        TransactionRecord record = new TransactionRecord(sender, recipient, amount, incentiveAmount);
        transactionRecordRepository.save(record);

        log.info("Recorded transaction: senderId={} -> recipientId={} amount={} incentive={}", senderId, recipientId, amount, incentiveAmount);
    }
}