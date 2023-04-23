library(tidyverse)

# Load required libraries
library(rvest)

# Function to parse text from a web page
parse_web_page <- function(url, selector) {
  # Read the HTML content of the web page
  page <- read_html(url)
  
  # Extract the text using the CSS selector
  text <- html_text(html_nodes(page, selector))
  
  # Return the parsed text
  return(text)
}



# Function to read API key from file
read_api_key <- function(file_path) {
  # Read the API key from the file
  api_key <- readLines(file_path)
  
  # Return the API key
  return(api_key)
}

# Function to summarize text using OpenAI API
summarize_text_with_oai <- function(text, api.key, model = "gpt-3.5-turbo", max_tokens = 64, verbose = F) {
  library(httr)
  
  # Define the API endpoint
  endpoint <- "https://api.openai.com/v1/chat/completions"
  
  # Set the request headers
  headers <- c(
    "Content-Type" = "application/json",
    "Authorization" = str_c("Bearer ", api.key)
  )
  
  prompt <- str_c("summarize in maximum 4 words which azure services about is this article:\n\n", text)
  # Set the request body (data)
  data <- list(
    "model" = model,
    "messages"= 
      list( list( "role" = "user", 
                  "content" = prompt)),
    "max_tokens" = max_tokens,
    "temperature" = 0
  )
  
  # Send the POST request
  response <- POST(url = endpoint, add_headers(.headers = headers), body = data, encode = "json")
  
  if (verbose) {
    # Print the response content
    message( str_c("Response: \n", content(response) %>% toJSON(pretty = T) ) )
  }
  
  # Extract the summarized text from the response
  summary <- content(response)$choices[[1]]$message$content 
  
  # Return the summarized text
  return(summary)
}




extract_text_data <- function (url, verbose = F, ...) {
  if (verbose) {
    # Print the response content
    message (str_c("requesting data for url [", url, "]") )
  }
  
    # extract text and labels
  blogpost.text <- parse_web_page(url, ".blog-postContent") %>%
    str_replace_all("\r\n( )*", " ")
  blogpost.labels <- parse_web_page(url, ".blog-topicLabels") %>%
    str_remove_all("^\r\n( )*|\r\n( )*$") %>%
    str_split("\r\n( )*") 
  blogpost.title <- parse_web_page(url, "h1")
  
  # note that file "openai-api.txt" must be present
  api.key <- 
    read_api_key("openai-api.txt") 
  
  # extract and clean summary with open ai
  services.summary <- summarize_text_with_oai(blogpost.text, api.key, verbose = verbose) %>% 
    str_remove_all("^( \t\t\t)*|[[:punct:]]$")
  
  result <- list(
    blogpost.title = blogpost.title,
    blogpost.labels = blogpost.labels,
    services.summary = services.summary
  )
  
  Sys.sleep(1)
  return(result)
}



blogpost.data.all <- 
  tibble()


for (post.year in 2021:2023) {
  
  for (post.month in 1:12) {
    
    for (post.page in 1:25) {
      
      # Construct the URL of the webpage
      url.archive <- str_c("https://azure.microsoft.com/en-us/blog/", post.year, "/", post.month, "/?Page=", post.page)
      
      if (parse_web_page(url.archive, ".blog-postList") %>%
          str_detect("No blog posts were found")) { 
        print( str_c("max number of post pages for ", post.year, "-", post.month, " is [", post.page - 1, "]") )
        break 
      }
      
      # Extract all href links from the "blog-postItem" class
      blogpost.links <-
        read_html(url.archive) %>%
        html_nodes('[data-test-element="recent-post-link"]') %>%
        html_attr("href")
      
      # adding references and summary for each blog post on the page
      page.data <-
        blogpost.links %>%
        tibble(blogpost.links = .) %>%
        mutate(url = str_c("https://azure.microsoft.com",blogpost.links),
               verbose = T) %>%
        mutate(data = pmap (., extract_text_data))
      
      # unpack all data and add additional data
      page.data.unpacked <-
        page.data %>% 
        mutate (year = post.year,
                month = str_pad(as.character(post.month), width = 2, side = "left", pad = "0"),
                post.page = post.page) %>%
        mutate(data = map(data, as_tibble)) %>%
        unnest(data) %>%
        unnest(blogpost.labels) %>%
        select(-verbose, -blogpost.links)
      
      blogpost.data.all <- 
        blogpost.data.all %>%
        rbind(page.data.unpacked)
      
    }
  }
  
  
}


source("custom_functions.R")

# to prepare df, use:
#
savefile = tribble(
   ~"sheetname" , ~"df",
   "blogpost.data.all", blogpost.data.all,
#   "blogpost.data.tags", blogpost.data.tags,
#   "sheet3", df3,
)
#
# usage:
save_to_excel_df("./", "report-", savefile)



##################################


blogpost.data.all  %>%
  write_csv("blogpost.data.all.csv")

##################################
