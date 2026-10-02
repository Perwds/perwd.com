package com.lootcrates.models;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class HistoryEntry {
   private final LocalDateTime timestamp;
   private final String crateId;
   private final String rewardName;
   private final int amount;
   private static final DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MM/dd/yyyy HH:mm");

   public HistoryEntry(LocalDateTime timestamp, String crateId, String rewardName, int amount) {
      this.timestamp = timestamp;
      this.crateId = crateId;
      this.rewardName = rewardName;
      this.amount = amount;
   }

   public HistoryEntry(String crateId, String rewardName, int amount) {
      this(LocalDateTime.now(), crateId, rewardName, amount);
   }

   public LocalDateTime getTimestamp() {
      return this.timestamp;
   }

   public String getFormattedDate() {
      return this.timestamp.format(formatter);
   }

   public String getCrateId() {
      return this.crateId;
   }

   public String getRewardName() {
      return this.rewardName;
   }

   public int getAmount() {
      return this.amount;
   }

   public String serialize() {
      return this.timestamp.toString() + ";" + this.crateId + ";" + this.rewardName + ";" + this.amount;
   }

   public static HistoryEntry deserialize(String data) {
      // The reward name may itself contain ';', so split off the first two fields and the last one.
      int first = data.indexOf(';');
      int second = first < 0 ? -1 : data.indexOf(';', first + 1);
      int last = data.lastIndexOf(';');
      if (second < 0 || last <= second) {
         return null;
      } else {
         try {
            LocalDateTime timestamp = LocalDateTime.parse(data.substring(0, first));
            String crateId = data.substring(first + 1, second);
            String rewardName = data.substring(second + 1, last);
            int amount = Integer.parseInt(data.substring(last + 1));
            return new HistoryEntry(timestamp, crateId, rewardName, amount);
         } catch (Exception var6) {
            return null;
         }
      }
   }
}
