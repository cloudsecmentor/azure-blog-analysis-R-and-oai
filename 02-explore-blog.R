library(tidyverse)
library(wordcloud2)
library(tm)


blog <- read_csv("./blogpost.data.all.csv")

blog.data.all <-
blog %>%
  left_join(blog %>% 
              pull(url) %>%
              unique() %>%
              tibble(url = .) %>%
              mutate( id = row_number())) %>% 
  group_by(id, year, month, post.page, url, blogpost.title, services.summary) %>%
  summarise(blogpost.labels = str_flatten(blogpost.labels, collapse = ', ')) %>%
  select(id, blogpost.labels, services.summary, blogpost.title, url, year, month, post.page) %>%
  ungroup()


########################################################################
## Review of tags

library(extrafont)
#font_import()
fonts()



tags <-
blog.data.all %>%
  mutate(tags = str_split(blogpost.labels, ", ") ) %>%
  unnest(tags) %>%
  count(id, tags) %>% select(-n) %>%
  mutate(tags = str_to_lower(tags)) %>%
  count(tags, name = "freq") 


tags %>%
  mutate(freq = 1/freq) %>%
  ggplot(aes(x = freq)) +
  geom_histogram(fill = "steelblue", color = "black") +
  labs(x = "1/Frequency", y = "Count", title = "Justification for not looking at freq < 4") +
  scale_y_log10() 


freq.mu <- 350
freq.sigma <- 200


tags %>%
  filter(freq >= 4) %>%
  mutate(freq = freq * exp(-(freq - freq.mu)^2 / (2 * freq.sigma^2))) %>%
  wordcloud2( fontFamily = "DIN Condensed", fontWeight = "normal" )




########################################################################


########################################################################
## Review of summary

tags.of.interest <-
tribble(
  ~tags,
  "storage",
  "cloud strategy",
  "virtual machines",
  "monitoring",
  "networking",
)



blog.with.tags.of.interest <-
blog.data.all %>%
  filter(blogpost.labels %>% 
           str_to_lower() %>%
           str_detect(
             tags.of.interest %>% 
               pull(tags) %>%
               str_c(collapse = "|")
           ))


tokens.summary <-
blog.with.tags.of.interest %>%
  mutate(tags = services.summary %>% 
           str_remove_all("[[:punct:]]") %>%
           str_split("( )+") ) %>%
  unnest(tags) %>%
  count(id, tags) %>% select(-n) %>%
  mutate(tags = str_to_lower(tags)) %>%
  count(tags, name = "freq") 


tokens.summary %>%
  mutate(freq = 1/freq) %>%
  ggplot(aes(x = freq)) +
  geom_histogram(fill = "steelblue", color = "black") +
  labs(x = "1/Frequency", y = "Count", title = "Justification for not looking at freq < 2") +
  scale_y_log10() 

custom.stopwords <- c(
  "azure",
  "services",
  "microsoft",
  "cloud",
  tm::stopwords()
)

tokens.summary %>%
  filter( !(tags %in% custom.stopwords) ) %>%
  filter(freq >= 2) %>% 
  # arrange(desc(freq)) %>% 
  # print() %>%
  wordcloud2( fontFamily = "DIN Condensed", fontWeight = "normal" )

# print out all tokens
strings <-
tokens.summary %>%
  filter( !(tags %in% custom.stopwords) ) %>%
  filter(freq >= 2) %>%
  arrange(desc(freq)) %>%
  pull(tags)

cat(paste0('"', strings, '",\n'), sep = "")

summary.filter <-
c(
  "storage",
  "management",
  "data",
  "cost",
  "service",
  "virtual",
  "backup",
  "monitor",
  "updates",
  "billing",
  "recovery",
  "network",
  "site",
  "application",
  "machines",
  "availability",
  "files",
  "monitoring",
  "vm",
  "disks",
  "gateway",
  "improvements",
  "disk",
  "premium"
  )


blog.with.tags.of.interest.summary.filter <-
blog.with.tags.of.interest %>%
  filter(services.summary %>% 
           str_to_lower() %>%
           str_detect(
             summary.filter %>% 
               str_c(collapse = "|")
           ))




########################################################################
## Save results

source("custom_functions.R")

# to prepare df, use:
#
savefile = tribble(
  ~"sheetname" , ~"df",
  "tags.and.summary.filter", blog.with.tags.of.interest.summary.filter,
  "blog.data.all", blog.data.all,
  #   "sheet3", df3,
)
#
# usage:

file.name <-
  tags.of.interest %>% 
  pull(tags) %>%
  str_c(collapse = "-") %>%
  str_c("-")

save_to_excel_df("./", file.name, savefile)


########################################################################


