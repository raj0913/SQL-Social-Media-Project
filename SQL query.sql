use ig_clone;

-- ** Subjective Questions Query ** --

-- 1.Are there any tables with duplicate or missing null values? If so, how would you handle them?

-- Checking Duplicate Values

SELECT id , count(*) AS duplicate_count
FROM users 
GROUP BY id
HAVING count(*) > 1;

-- Handling Duplicate Values

WITH DuplicateRecords AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY id ORDER BY id) AS row_num FROM users)
DELETE FROM users
WHERE id IN (SELECT id FROM DuplicateRecords WHERE row_num > 1);

-- Identifying and Handling Null Values

SELECT *
FROM users
WHERE id IS NULL OR username IS NULL or created_at is NULL ;

DELETE FROM users
WHERE id IS NULL OR username IS NULL or created_at is NULL ;

-- 2.What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?
SELECT u.id AS user_id, u.username, 
COUNT(DISTINCT p.id) AS number_Of_posts,
COUNT(DISTINCT l.photo_id) AS number_of_likes, 
COUNT(DISTINCT c.id) AS number_of_comments 
FROM users u
LEFT JOIN photos p ON u.id =p.user_id
LEFT JOIN likes l ON u.id = l.user_id
LEFT JOIN comments c ON u.id = c.user_id 
GROUP BY u.id, u.username;

-- 3.Calculate the average number of tags per post (photo_tags and photos tables).
SELECT ROUND(AVG(tags)) AS avg_tags_per_post
FROM (SELECT p.id,COUNT(t.tag_id) AS tags
FROM photos p
LEFT JOIN photo_tags t ON p.id = t.photo_id GROUP BY p.id) AS num_tags;

-- 4.Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.
WITH Total_likes AS (
SELECT u.username , count(l.user_id) AS total_likes 
FROM users u 
LEFT JOIN likes l 
ON u.id = l.user_id 
GROUP BY u.username ),
Total_comments AS (
SELECT u.username , count(c.user_id) AS total_comments 
FROM users u 
LEFT JOIN comments c 
ON u.id = c.user_id 
GROUP BY u.username )
SELECT l.username , l.total_likes , c.total_comments ,(l.total_likes + c.total_comments) as engagement_rate,
DENSE_RANK() OVER (ORDER BY (l.total_likes + c.total_comments) DESC) AS engagement_rate_rank 
FROM Total_likes l 
JOIN Total_comments c 
ON l.username = c.username
LIMIT 20;

-- 5.Which users have the highest number of followers and followings?

WITH count_of_followers AS (
    SELECT follower_id, COUNT(follower_id) AS follower_count
    FROM follows
    GROUP BY follower_id
), count_of_followee AS (
    SELECT followee_id, COUNT(followee_id) AS followee_count
    FROM follows
    GROUP BY followee_id
)
SELECT u.id, u.username, COALESCE(a.follower_count, 0) AS follower_count,
COALESCE(b.followee_count, 0) AS followee_count
FROM users AS u LEFT JOIN count_of_followers AS a
ON u.id = a.follower_id LEFT JOIN count_of_followee AS b
ON u.id = b.followee_id 
ORDER BY follower_count DESC, followee_count DESC
limit 20;

-- 6.Calculate the average engagement rate (likes, comments) per post for each user.
WITH Post_likes AS (SELECT distinct photo_id, count(user_id) AS like_count
FROM likes GROUP BY photo_id), 
Post_comments AS (SELECT distinct photo_id, count(user_id) AS comment_count
FROM comments GROUP BY photo_id),
Total_likes_n_comments AS (
	SELECT distinct p.id AS photo_id, p.user_id,
	coalesce(pl.like_count, 0) AS like_count,
	coalesce(pc.comment_count, 0) AS comment_count,
	coalesce(pl.like_count, 0) + coalesce(pc.comment_count, 0) AS total_engagement
    FROM photos  as p
	LEFT JOIN Post_likes as pl ON p.id=pl.photo_id
	LEFT JOIN Post_comments as pc ON p.id=pc.photo_id),
User_engagement AS (
      SELECT distinct t.user_id, u.username,round(avg(t.total_engagement),0) AS avg_engagement_rate
      FROM Total_likes_n_comments as t
      Join users as u on t.user_id = u.id
	  GROUP BY  t.user_id)
SELECT distinct user_id, username, avg_engagement_rate
FROM  User_engagement 
ORDER BY avg_engagement_rate desc;

-- 7.Get the list of users who have never liked any post (users and likes tables)

SELECT id, username 
FROM users 
WHERE id NOT IN  (SELECT user_id FROM likes);

-- 8.How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalized and engaging ad campaigns?

-- Most used tags
SELECT t.tag_name, COUNT(pt.photo_id) AS tag_usage_count
FROM tags t
JOIN photo_tags pt ON t.id = pt.tag_id
GROUP BY t.tag_name
ORDER BY tag_usage_count DESC;

-- 9.	Are there any correlations between user activity levels and specific content types (e.g., photos, videos, reels)? How can this information guide content creation and curation strategies?

WITH photo_engagement AS (
SELECT p.id AS photo_id, p.user_id,
COUNT(DISTINCT l.user_id) AS likes_count, COUNT(DISTINCT c.id) AS comments_count
FROM photos p LEFT JOIN likes l ON p.id = l.photo_id
LEFT JOIN comments c ON p.id = c.photo_id
GROUP BY p.id, p.user_id
), photo_with_tags AS (
    SELECT pe.user_id, t.tag_name, pe.photo_id,
	(pe.likes_count + pe.comments_count) AS total_engagement
    FROM photo_engagement pe
    JOIN photo_tags pt ON pe.photo_id = pt.photo_id
    JOIN tags t ON pt.tag_id = t.id
)
SELECT tag_name AS content_type,
    COUNT(DISTINCT photo_id) AS total_photos,
    COUNT(DISTINCT user_id) AS active_users,
    AVG(total_engagement) AS avg_engagement_per_photo
FROM photo_with_tags
GROUP BY tag_name
ORDER BY avg_engagement_per_photo DESC;


-- 10.Calculate the total number of likes, comments, and photo tags for each user.

WITH like_count AS ( SELECT distinct user_id,count(*) AS num_of_likes FROM likes
GROUP BY user_id),
comment_count AS ( SELECT user_id,count(id) AS num_of_comments FROM comments
GROUP BY user_id),
tag_count AS ( SELECT u.id,count(tag_id) AS num_of_phototags
FROM photos p JOIN photo_tags pt ON p.id=pt.photo_id
JOIN users u  ON u.id=p.user_id
GROUP BY u.id)
SELECT u.id as UserID, u.username as UserName,coalesce(num_of_likes,0) num_of_likes,
coalesce(num_of_comments,0) num_of_comments,coalesce(num_of_phototags,0)num_of_phototags
FROM users u LEFT JOIN like_count l ON u.id=l.user_id
LEFT JOIN comment_count c ON u.id=c.user_id
LEFT join tag_count  p ON u.id=p.id;

-- 11.Rank users based on their total engagement (likes, comments, shares) over a month.

WITH Post_likes AS (SELECT distinct user_id, count(*) AS like_count
FROM likes GROUP BY user_id),
Post_comments AS (SELECT distinct user_id, count(*) AS comment_count
FROM comments GROUP BY user_id),
Total_likes_n_comments AS ( SELECT distinct u.id AS User_id, u.username,
coalesce(pl.like_count, 0) AS like_count,
coalesce(pc.comment_count, 0) AS comment_count,
coalesce(pl.like_count, 0) + coalesce(pc.comment_count, 0) AS total_engagement
FROM users as u LEFT JOIN Post_likes as pl ON u.id=pl.user_id
LEFT JOIN Post_comments as pc ON u.id=pc.user_id)
SELECT User_id , username AS Username , like_count , comment_count , total_engagement ,
dense_rank() over (order by total_engagement desc) as User_rank 
FROM Total_likes_n_comments;

-- 12.Retrieve the hashtags that have been used in posts with the highest average number of likes. Use a CTE to calculate the average likes for each hashtag first.

With Likes_Count as ( SELECT photo_id,count(user_id) AS LikesCount
FROM likes GROUP BY photo_id)
SELECT t.tag_name , round(AVG(c.LikesCount),0) AS Avg_likes
FROM tags t JOIN photo_tags pt ON t.id = pt.tag_id
JOIN Likes_Count c ON pt.photo_id = c.photo_id
GROUP BY t.tag_name
ORDER BY Avg_likes DESC;

-- 13.Retrieve the users who have started following someone after being followed by that person

SELECT f1.follower_id AS Followed_User, f1.followee_id AS Follower_User
FROM follows AS f1
JOIN follows AS f2 ON f1.follower_id = f2.followee_id 
AND f1.followee_id = f2.follower_id
AND f1.created_at > f2.created_at;


-- ** Subjective Questions ** --

-- 1.Based on user engagement and activity levels, which users would you consider the most loyal or valuable? How would you reward or incentivize these users?

with likes_count as (
    SELECT distinct user_id,count(*) AS num_of_likes FROM likes
    GROUP BY user_id),
comments_count as (
    SELECT user_id,count(id) AS num_of_comments FROM comments
    GROUP BY user_id),
photo_counts as (
	SELECT user_id,
	COUNT(*) AS num_of_photos FROM photos 
	GROUP BY user_id),
phototags_count as (
    SELECT p.user_id,count(pt.tag_id) AS num_of_phototags
    FROM photos p
    JOIN photo_tags as pt ON p.user_id=pt.photo_id
    GROUP BY p.user_id),
Count_of_followers as (
	SELECT follower_id , count(follower_id) AS follower_count ,
	count(followee_id) AS followee_count
	FROM follows 
	GROUP BY follower_id)

SELECT u.id AS UserID, u.username AS UserName,
       coalesce(l.num_of_likes,0) AS  num_of_likes,
	   coalesce(c.num_of_comments,0) AS num_of_comments,
       coalesce(pp.num_of_photos,0) AS num_of_photos,
       coalesce(p.num_of_phototags,0) AS num_of_phototags,
	   coalesce(f.follower_count,0) AS  follower_count,
	   coalesce(f.followee_count,0) AS  followee_count,
	   coalesce((coalesce(l.num_of_likes,0) + coalesce(c.num_of_comments,0)+  coalesce(pp.num_of_photos,0)),0) AS engagement_rate,
DENSE_RANK() OVER (ORDER BY (coalesce(l.num_of_likes,0) + coalesce(c.num_of_comments,0)+ coalesce(pp.num_of_photos,0)) DESC) 
AS engagement_rate_rank 
FROM users u LEFT JOIN likes_count as l ON u.id=l.user_id
LEFT JOIN comments_count as c ON u.id=c.user_id
LEFT JOIN photo_counts as pp on u.id = pp.user_id
LEFT join phototags_count as  p ON u.id=p.user_id
LEFT JOIN Count_of_followers as f ON u.id = f.follower_id
ORDER BY  engagement_rate_rank;

-- 2.For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?

with likes_count as (
    SELECT distinct user_id,count(*) AS num_of_likes FROM likes
    GROUP BY user_id),
comments_count as (
    SELECT user_id,count(id) AS num_of_comments FROM comments
    GROUP BY user_id),
photo_counts as (
	SELECT user_id,
	COUNT(*) AS num_of_photos FROM photos 
	GROUP BY user_id),
phototags_count as (
    SELECT p.user_id,count(pt.tag_id) AS num_of_phototags
    FROM photos p
    JOIN photo_tags as pt ON p.user_id=pt.photo_id
    GROUP BY p.user_id),
Count_of_followers as (
	SELECT follower_id , count(follower_id) AS follower_count ,
	count(followee_id) AS followee_count
	FROM follows 
	GROUP BY follower_id)

SELECT u.id AS UserID, u.username AS UserName,
       coalesce(l.num_of_likes,0) AS  num_of_likes,
	   coalesce(c.num_of_comments,0) AS num_of_comments,
       coalesce(pp.num_of_photos,0) AS num_of_photos,
       coalesce(p.num_of_phototags,0) AS num_of_phototags,
	   coalesce(f.follower_count,0) AS  follower_count,
	   coalesce(f.followee_count,0) AS  followee_count,
	   coalesce((coalesce(l.num_of_likes,0) + coalesce(c.num_of_comments,0)+  coalesce(pp.num_of_photos,0)),0) AS engagement_rate,
DENSE_RANK() OVER (ORDER BY (coalesce(l.num_of_likes,0) + coalesce(c.num_of_comments,0)+ coalesce(pp.num_of_photos,0)) ASC) 
AS engagement_rate_rank 
FROM users u LEFT JOIN likes_count as l ON u.id=l.user_id
LEFT JOIN comments_count as c ON u.id=c.user_id
LEFT JOIN photo_counts as pp on u.id = pp.user_id
LEFT join phototags_count as  p ON u.id=p.user_id
LEFT JOIN Count_of_followers as f ON u.id = f.follower_id
ORDER BY  engagement_rate_rank;


-- 3.Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?

with Likes as (
SELECT photo_id, COUNT(*) AS total_likes 
FROM likes GROUP BY photo_id),
Comments as (  
  SELECT photo_id, COUNT(*) AS total_comments 
  FROM comments GROUP BY photo_id)
SELECT t.tag_name,
    COUNT(pt.photo_id) AS total_posts,
    COALESCE(SUM(l.total_likes), 0) AS total_likes,
    COALESCE(SUM(c.total_comments), 0) AS total_comments,
    ROUND((COALESCE(SUM(l.total_likes), 0) + COALESCE(SUM(c.total_comments), 0)) / COUNT(pt.photo_id),0) AS average_engagement
FROM tags t JOIN photo_tags pt ON t.id = pt.tag_id
LEFT JOIN Likes l on pt.photo_id = l.photo_id
LEFT JOIN Comments c on pt.photo_id = c.photo_id
group by t.tag_name
order by average_engagement desc
limit 10;

-- 4.Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times? How can these insights inform targeted marketing campaigns?

With Likes AS (SELECT photo_id, COUNT(*) AS Total_likes 
FROM likes GROUP BY photo_id) , 
Comments AS (SELECT photo_id, COUNT(*) AS Total_comments 
FROM comments GROUP BY photo_id) 
SELECT DATE_FORMAT(p.created_dat, '%H') AS Hour_of_day,
    DAYNAME(p.created_dat) AS Day_of_week,
    COUNT(p.id) AS Total_posts,
    COALESCE(SUM(L.Total_likes), 0) AS Total_likes,
    COALESCE(SUM(c.Total_comments), 0) AS Total_comments,
    ROUND((COALESCE(SUM(l.Total_likes), 0) + COALESCE(SUM(c.Total_comments), 0)) / COUNT(p.id),0) 
    AS Average_engagement
FROM photos AS p LEFT JOIN Likes as l ON p.id = l.photo_id
LEFT JOIN Comments as c ON p.id = c.photo_id
GROUP BY Hour_of_day,Day_of_week ;

-- 5.Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? How would you approach and collaborate with these influencers?

WITH Followers AS (
    SELECT f.follower_id AS user_id, COUNT(f.follower_id) AS follower_count
    FROM follows f GROUP BY f.follower_id),
total_likes_n_comments AS (
    SELECT p.user_id,COUNT(DISTINCT l.user_id) AS total_likes,
	COUNT(DISTINCT c.id) AS total_comments FROM photos p
    LEFT JOIN likes l ON p.id = l.photo_id LEFT JOIN comments c ON p.id = c.photo_id
    GROUP BY p.user_id),
Final AS ( SELECT u.id, u.username as Username, coalesce(sum(f.follower_count),0) as Follower_count,
	coalesce(sum(t.total_likes),0) AS Total_likes,
	coalesce(sum(t.total_comments),0) AS Total_comments,
	Round(coalesce(sum(t.total_likes), 0) + coalesce(sum(t.total_comments),0) / coalesce(count(f.follower_count),1),0) 
	AS Engagement_rate FROM users u
    LEFT JOIN Followers f ON u.id = f.user_id
    LEFT JOIN total_likes_n_comments t ON u.id = t.user_id
    group by u.id ,u.username )
SELECT id AS User_id, Username, Follower_count, Total_likes, Total_comments, Engagement_rate
FROM Final 
where Follower_count != 0
ORDER BY engagement_rate DESC, follower_count DESC
limit 10;

-- 6.Based on user behavior and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations?

With Likes as (SELECT user_id, COUNT(*) AS likes_count 
 FROM likes  GROUP BY user_id),
Comments as (SELECT user_id, COUNT(*) AS comments_count 
 FROM comments GROUP BY user_id) 
 SELECT u.id AS user_id, u.username,
    COALESCE(SUM(likes_count), 0) AS Total_likes, COALESCE(SUM(comments_count), 0) AS Total_comments,
    COALESCE(COUNT(DISTINCT p.id), 0) AS Total_photos,
    CASE WHEN COALESCE(COUNT(DISTINCT p.id), 0) = 0 THEN 0 
	ELSE (COALESCE(SUM(likes_count), 0) + COALESCE(SUM(comments_count), 0)) / COALESCE(COUNT(DISTINCT p.id), 1) 
    END AS Engagement_rate,
    CASE 
        WHEN COALESCE(COUNT(DISTINCT p.id), 0) = 0 THEN 'Inactive Users'
        WHEN (COALESCE(SUM(likes_count), 0) + COALESCE(SUM(comments_count), 0)) / COALESCE(COUNT(DISTINCT p.id), 1) > 150 THEN 'Ative Users'
        WHEN (COALESCE(SUM(likes_count), 0) + COALESCE(SUM(comments_count), 0)) / COALESCE(COUNT(DISTINCT p.id), 1) BETWEEN 100 AND 150 
        THEN 'Moderately Active Users' ELSE 'Inactive Users' END AS Engagement_level
FROM users as u
LEFT JOIN photos p ON u.id = p.user_id
LEFT JOIN Likes as l ON u.id = l.user_id
LEFT JOIN Comments as c ON u.id = c.user_id
GROUP BY u.id, u.username
ORDER BY engagement_rate DESC;


