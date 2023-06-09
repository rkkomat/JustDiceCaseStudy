library(tidyverse)  # Loading necessary packages
library(lubridate)
library(dplyr)
library(plotrix)
library(scales)
library(ggplot2)

# Step 1:Loading required datasets
adspend <- read_csv("raw_data/adspend.csv")
installs <- read_csv("raw_data/installs.csv")
payouts <- read_csv("raw_data/payouts.csv")
revenue <- read_csv("raw_data/revenue.csv")

# Step 2: Cleaning the datasets(Removing duplicates)
clean_adspend <- adspend %>% distinct()  # Remove duplicate rows in adspend
clean_installs <- installs %>% distinct()  # Remove duplicate rows in installs
clean_payouts <- payouts %>% distinct()  # Remove duplicate rows in payouts
clean_revenue <- revenue %>% distinct()  # Remove duplicate rows in revenue

# Check for null values in each dataset
colSums(is.na(clean_adspend))
colSums(is.na(clean_installs))
colSums(is.na(clean_payouts))
colSums(is.na(clean_revenue)) #No null values, data is cleaned

# Step 3: Start analysis
# Renaming a few column names to be more descriptive
colnames(clean_adspend)[5] <- "adspend_value"
colnames(clean_installs)[5] <- "install_date"
colnames(clean_payouts)[2] <- "payout_date"
colnames(clean_payouts)[3] <- "Payout_price"
colnames(clean_revenue)[2] <- "revenue_date"
colnames(clean_revenue)[3] <- "revenue_value"

# Merging the required datasets using inner join
install_payouts <- inner_join(clean_installs, clean_payouts,
                              by = "install_id", multiple = "all")

install_revenue <- inner_join(clean_installs, clean_revenue,
                              by = "install_id", multiple = "all")

payout_revenue <- inner_join(install_revenue, install_payouts,
                             by = "install_id", multiple = "all")

# Perform exploratory data analysis (EDA)
# Aggregate the data by network_id and calculate total and average payouts
install_payouts %>% 
  group_by(network_id) %>% 
  summarise(total_payouts = sum(Payout_price),
            average_payout = mean(Payout_price),
            total_installs = n()) %>% 
  arrange(desc(total_payouts))

# Aggregate the data by app_id and calculate total and average revenue
install_revenue %>%                                 
  group_by(app_id) %>% 
  summarise(total_revenue = sum(revenue_value),
            average_revenue = mean(revenue_value),
            total_installs = n()) %>% 
  arrange(desc(total_revenue))

# Download the analyzed dataset to perform visualization on a BT tool.
write.csv(install_payouts, file = "./Cleaned_Dataset/install_payouts.csv")
write.csv(install_revenue, file = "./Cleaned_Dataset/install_revenue.csv")

# Calculate KPIs
Total_revenue <- sum(install_revenue$revenue_value) # total revenue generated from the app
total_payouts <- sum(install_payouts$Payout_price) # total payouts made to affiliate networks
Total_adv <- sum(clean_adspend$adspend_value) # total advertising cost incurred
Profit_KPI <- Total_revenue - (total_payouts + Total_adv) # total profit generated

revenue_per_user <- sum(payout_revenue$revenue_value) / length(unique(payout_revenue$install_id)) # average revenue per user
Life_time_value <- revenue_per_user * 6 # lifetime value of a user (assuming an average user uses the app for 6 months)
revenue_by_country <- aggregate(payout_revenue$revenue_value,
                                by=list(payout_revenue$country_id.x),
                                FUN=sum) # total revenue generated by country
colnames(revenue_by_country) <- c("Country", "Revenue")

revenue_per_installation <- sum(payout_revenue$revenue_value) / nrow(payout_revenue) # average revenue per installation


# Print KPIs
cat("Total Revenue: $", Total_revenue, "\n")
cat("Total Payouts: $", total_payouts, "\n")
cat("Total Advertising Cost: $", Total_adv, "\n")
cat("Total Profit: $", Profit_KPI, "\n")

# Visualize payout by month
install_payouts$month <- month(install_payouts$payout_date)

install_payouts %>% 
  mutate(month = month(install_date)) %>% 
  group_by(month) %>% 
  summarise(total_payout = sum(Payout_price)) %>% 
  mutate(fill_color = rescale(total_payout)) %>%
  ggplot(aes(x = month, y = total_payout, fill = fill_color))+
  geom_text(aes(label = ceiling(total_payout)), 
            position = position_dodge(width = 1), vjust = -0.5)+
  geom_col(position = "dodge")+
  scale_x_continuous(breaks = 1:12, labels = month.abb)+
  scale_fill_gradient(low = "#b3ffff", high = "#004d4d")+
  labs(title = "Total Payout by Months", x = "Month", y= "Total Payouts (USD)",
       subtitle = "Monthly Total Payouts from JustDice to Affiliate Networks, 2022")+
  theme_minimal()

# Visualize revenue by month
install_revenue %>% 
  mutate(month = month(revenue_date)) %>% 
  group_by(month) %>% 
  summarise(total_revenue = sum(revenue_value)) %>% 
  ggplot(aes(x = month, y = total_revenue), colour = "black", size = 0.2)+
  geom_segment( aes(x=month, xend=month, y=0, yend=total_revenue)) +
  geom_point( size=3, color="red", fill=alpha("red", 0.3), alpha=0.7, shape=21, stroke=2)+
  geom_text(aes(label = floor(total_revenue)), 
            position = position_dodge(width = 0.5), vjust = -1.5)+
  scale_x_continuous(breaks = 1:12, labels = month.abb)+
  labs(title = "Total Revenue by Months", x = "Month", y= "Total Revenue (USD)",
       subtitle = "Monthly Total Revenue of JustDice in 2022")+
  theme_minimal()

app_data <- payout_revenue %>% 
  group_by(app_id.x) %>% 
  summarise(revenue = sum(revenue_value),
            payout = sum(Payout_price),
            ROI = ((sum(revenue_value) - sum(Payout_price))/ sum(Payout_price))*100)

write.csv(clean_adspend, file = "./Cleaned_Dataset/cleaned_adspend.csv")
write.csv(clean_installs, file = "./Cleaned_Dataset/cleaned_installs.csv")
write.csv(clean_payouts, file = "./Cleaned_Dataset/cleaned_payouts.csv")
write.csv(clean_revenue, file = "./Cleaned_Dataset/cleaned_revenue.csv")
