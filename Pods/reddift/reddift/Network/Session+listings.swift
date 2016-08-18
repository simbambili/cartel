//
//  Session+listings.swift
//  reddift
//
//  Created by sonson on 2015/05/19.
//  Copyright (c) 2015年 sonson. All rights reserved.
//

import Foundation

/**
The sort method for listing Link object, "/r/[subreddit]/[sort]" or "/[sort]".
*/
enum PrivateLinkSortBy {
    case Controversial
    case Top
    
    var path: String {
        switch self {
        case .Controversial:
            return "/controversial"
        case .Top:
            return "/hot"
        }
    }
}

extension Session {

    /**
    Get the comment tree for a given Link article.
    If supplied, comment is the ID36 of a comment in the comment tree for article. This comment will be the (highlighted) focal point of the returned view and context will be the number of parents shown.
    
    - parameter link: Link from which comment will be got.
    - parameter sort: The type of sorting.
    - parameter comments: If supplied, comment is the ID36 of a comment in the comment tree for article. Default is nil.
    - parameter depth: The maximum depth of subtrees in the thread. Default is nil.
    - parameter limit: The maximum number of comments to return. Default is nil.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    public func getArticles(link: Link, sort: CommentSort, comments: [String]? = nil, depth: Int? = nil, limit: Int? = nil, completion: (Result<(Listing, Listing)>) -> Void) throws -> NSURLSessionDataTask {
        var parameter: [String:String] = ["sort":sort.type, "showmore":"True"]
        if let depth = depth {
            parameter["depth"] = "\(depth)"
        }
        if let limit = limit {
            parameter["limit"] = "\(limit)"
        }
        if let comments = comments {
            let commaSeparatedIDString = comments.joinWithSeparator(",")
            parameter["comment"] = commaSeparatedIDString
        }
        guard let request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(baseURL, path:"/comments/" + link.id + ".json", parameter:parameter, method:"GET", token:token)
            else { throw ReddiftError.URLError.error }
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            self.updateRateLimitWithURLResponse(response)
            
            let result: Result<(Listing, Listing)> = resultFromOptionalError(Response(data: data, urlResponse: response), optionalError:error)
                .flatMap(response2Data)
                .flatMap(data2Json)
                .flatMap(json2RedditAny)
                .flatMap(redditAny2Object)
            completion(result)
        })
        task.resume()
        return task
    }
    
    /**
    Get Links from all subreddits or user specified subreddit.
    
    - parameter paginator: Paginator object for paging contents.
    - parameter subreddit: Subreddit from which Links will be gotten.
    - parameter integratedSort: The original type of sorting a list, .Controversial, .Top, .Hot, or .New.
    - parameter TimeFilterWithin: The type of filtering contents. When integratedSort is .Hot or .New, this parameter is ignored.
    - parameter limit: The maximum number of comments to return. Default is 25.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    public func getList(paginator: Paginator, subreddit: SubredditURLPath?, sort: LinkSortType, timeFilterWithin: TimeFilterWithin, limit: Int = 25, completion: (Result<Listing>) -> Void) throws -> NSURLSessionDataTask {
        do {
            switch sort {
            case .Controversial:
                return try getList(paginator, subreddit: subreddit, privateSortType: .Controversial, timeFilterWithin: timeFilterWithin, limit: limit, completion: completion)
            case .Top:
                return try getList(paginator, subreddit: subreddit, privateSortType: .Top, timeFilterWithin: timeFilterWithin, limit: limit, completion: completion)
            case .New:
                return try getNewOrHotList(paginator, subreddit: subreddit, type: "new", limit:limit, completion: completion)
            case .Hot:
                return try getNewOrHotList(paginator, subreddit: subreddit, type: "hot", limit:limit, completion: completion)
            }
        } catch { throw error }
    }
    
    /**
    Get Links from all subreddits or user specified subreddit.
    
    - parameter paginator: Paginator object for paging contents.
    - parameter subreddit: Subreddit from which Links will be gotten.
    - parameter sort: The type of sorting a list.
    - parameter TimeFilterWithin: The type of filtering contents.
    - parameter limit: The maximum number of comments to return. Default is 25.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    func getList(paginator: Paginator, subreddit: SubredditURLPath?, privateSortType: PrivateLinkSortBy, timeFilterWithin: TimeFilterWithin, limit: Int = 25, completion: (Result<Listing>) -> Void) throws -> NSURLSessionDataTask {
        let parameter = paginator.addParametersToDictionary([
            "limit"    : "\(limit)",
            "show"     : "all",
//          "sr_detail": "true",
            "t"        : timeFilterWithin.param
        ])
        var path = "\(privateSortType.path).json"
        if let subreddit = subreddit { path = "\(subreddit.path)\(privateSortType.path).json" }
        guard let request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(baseURL, path:path, parameter:parameter, method:"GET", token:token)
            else { throw ReddiftError.URLError.error }
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            self.updateRateLimitWithURLResponse(response)
            let result: Result<Listing> = resultFromOptionalError(Response(data: data, urlResponse: response), optionalError:error)
                .flatMap(response2Data)
                .flatMap(data2Json)
                .flatMap(json2RedditAny)
                .flatMap(redditAny2Object)
            completion(result)
        })
        task.resume()
        return task
    }
    
    /**
    Get hot Links from all subreddits or user specified subreddit.
    
    - parameter paginator: Paginator object for paging contents.
    - parameter subreddit: Subreddit from which Links will be gotten.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    func getHotList(paginator: Paginator, subreddit: SubredditURLPath?, limit: Int = 25, completion: (Result<Listing>) -> Void) throws -> NSURLSessionDataTask {
        do {
            return try getNewOrHotList(paginator, subreddit: subreddit, type: "hot", limit:limit, completion: completion)
        } catch { throw error }
    }
    
    /**
    Get new Links from all subreddits or user specified subreddit.
    
    - parameter paginator: Paginator object for paging contents.
    - parameter subreddit: Subreddit from which Links will be gotten.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    func getNewList(paginator: Paginator, subreddit: SubredditURLPath?, limit: Int = 25, completion: (Result<Listing>) -> Void) throws -> NSURLSessionDataTask {
        do {
            return try getNewOrHotList(paginator, subreddit: subreddit, type: "new", limit:limit, completion: completion)
        } catch { throw error }
    }
    
    /**
    Get hot or new Links from all subreddits or user specified subreddit.
    
    - parameter paginator: Paginator object for paging contents.
    - parameter subreddit: Subreddit from which Links will be gotten.
    - parameter type: "new" or "hot" as type.
    - parameter limit: The maximum number of comments to return. Default is 25.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    func getNewOrHotList(paginator: Paginator, subreddit: SubredditURLPath?, type: String, limit: Int = 25, completion: (Result<Listing>) -> Void) throws -> NSURLSessionDataTask {
        let parameter = paginator.addParametersToDictionary([
            "limit"    : "\(limit)",
            //            "sr_detail": "true",
            "show"     : "all",
            ])
        var path = "\(type).json"
        if let subreddit = subreddit { path = "\(subreddit.path)/\(type).json" }
        guard let request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(baseURL, path:path, parameter:parameter, method:"GET", token:token)
            else { throw ReddiftError.URLError.error }
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            self.updateRateLimitWithURLResponse(response)
            let result: Result<Listing> = resultFromOptionalError(Response(data: data, urlResponse: response), optionalError:error)
                .flatMap(response2Data)
                .flatMap(data2Json)
                .flatMap(json2RedditAny)
                .flatMap(redditAny2Object)
            completion(result)
        })
        task.resume()
        return task
    }
    
    /**
    The Serendipity content.
    But this endpoints return invalid redirect URL...
    I don't know how this URL should be handled....
    
    - parameter subreddit: Specified subreddit to which you would like to get random link
    - returns: Data task which requests search to reddit.com.
    */
    public func getRandom(subreddit: Subreddit? = nil, completion: (Result<(Listing, Listing)>) -> Void) throws -> NSURLSessionDataTask {
        var path = "/random"
        if let subreddit = subreddit { path = subreddit.url + "/random" }
        guard let request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(baseURL, path:path, method:"GET", token:token)
            else { throw ReddiftError.URLError.error }
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            self.updateRateLimitWithURLResponse(response)
            let result: Result<(Listing, Listing)> = resultFromOptionalError(Response(data: data, urlResponse: response), optionalError:error)
                .flatMap(response2Data)
                .flatMap(data2Json)
                .flatMap(json2RedditAny)
                .flatMap(redditAny2Object)
            completion(result)
        })
        task.resume()
        return task
    }
    
    // MARK: BDT does not cover following methods.
    
    /**
    Related page: performs a search using title of article as the search query.
    
    - parameter paginator: Paginator object for paging contents.
    - parameter thing:  Thing object to which you want to obtain the contents that are related.
    - parameter limit: The maximum number of comments to return. Default is 25.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    public func getRelatedArticles(paginator: Paginator, thing: Thing, limit: Int = 25, completion: (Result<(Listing, Listing)>) -> Void) throws -> NSURLSessionDataTask {
        let parameter = paginator.addParametersToDictionary([
            "limit"    : "\(limit)",
            //            "sr_detail": "true",
            "show"     : "all",
        ])
        
        guard let request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(baseURL, path:"/related/" + thing.id, parameter:parameter, method:"GET", token:token)
            else { throw ReddiftError.URLError.error }
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            self.updateRateLimitWithURLResponse(response)
            let result: Result<(Listing, Listing)> = resultFromOptionalError(Response(data: data, urlResponse: response), optionalError:error)
                .flatMap(response2Data)
                .flatMap(data2Json)
                .flatMap(json2RedditAny)
                .flatMap(redditAny2Object)
            completion(result)
        })
        task.resume()
        return task
    }
    
    /**
    Return a list of other submissions of the same URL.
    
    - parameter paginator: Paginator object for paging contents.
    - parameter thing:  Thing object by which you want to obtain the same URL is mentioned.
    - parameter limit: The maximum number of comments to return. Default is 25.
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    public func getDuplicatedArticles(paginator: Paginator, thing: Thing, limit: Int = 25, completion: (Result<(Listing, Listing)>) -> Void) throws -> NSURLSessionDataTask {
        let parameter = paginator.addParametersToDictionary([
            "limit"    : "\(limit)",
//            "sr_detail": "true",
            "show"     : "all"
        ])
        guard let request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(baseURL, path:"/duplicates/" + thing.id, parameter:parameter, method:"GET", token:token)
            else { throw ReddiftError.URLError.error }
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            self.updateRateLimitWithURLResponse(response)
            let result: Result<(Listing, Listing)> = resultFromOptionalError(Response(data: data, urlResponse: response), optionalError:error)
                .flatMap(response2Data)
                .flatMap(data2Json)
                .flatMap(json2RedditAny)
                .flatMap(redditAny2Object)
            completion(result)
        })
        task.resume()
        return task
    }
    
    /**
    Get a listing of links by fullname.
    
    :params: links A list of Links
    - parameter completion: The completion handler to call when the load request is complete.
    - returns: Data task which requests search to reddit.com.
    */
    public func getLinksById(links: [Link], completion: (Result<Listing>) -> Void) throws -> NSURLSessionDataTask {
        let fullnameList: [String] = links.map({ (link: Link) -> String in link.name })
        guard let request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(baseURL, path:"/by_id/" + fullnameList.joinWithSeparator(","), method:"GET", token:token)
            else { throw ReddiftError.URLError.error }
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            self.updateRateLimitWithURLResponse(response)
            let result: Result<Listing> = resultFromOptionalError(Response(data: data, urlResponse: response), optionalError:error)
                .flatMap(response2Data)
                .flatMap(data2Json)
                .flatMap(json2RedditAny)
                .flatMap(redditAny2Object)
            completion(result)
        })
        task.resume()
        return task
    }
}
