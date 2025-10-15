-- Marketing Campaign Performance Analysis
-- Comprehensive analysis of marketing campaign performance across all channels

WITH campaign_base_metrics AS (
    -- Base campaign metrics
    SELECT 
        c.campaign_id,
        c.campaign_name,
        c.channel,
        c.sub_channel,
        c.start_date,
        c.end_date,
        c.budget,
        c.target_audience,
        c.objective,
        c.status,
        
        -- Date calculations
        DATEDIFF(day, c.start_date, c.end_date) as campaign_duration_days,
        DATEDIFF(day, c.start_date, GETDATE()) as days_since_start,
        DATEDIFF(day, c.end_date, GETDATE()) as days_since_end,
        
        -- Budget calculations
        c.budget / NULLIF(DATEDIFF(day, c.start_date, c.end_date), 0) as daily_budget,
        c.budget / NULLIF(DATEDIFF(day, c.start_date, c.end_date), 0) / 24 as hourly_budget
        
    FROM campaigns c
),

touchpoint_metrics AS (
    -- Touchpoint and interaction metrics
    SELECT 
        t.campaign_id,
        COUNT(DISTINCT t.customer_id) as unique_customers_reached,
        COUNT(t.touchpoint_id) as total_touchpoints,
        SUM(t.cost) as total_touchpoint_cost,
        AVG(t.cost) as avg_cost_per_touchpoint,
        
        -- Interaction metrics
        SUM(CASE WHEN t.interaction_type = 'click' THEN 1 ELSE 0 END) as total_clicks,
        SUM(CASE WHEN t.interaction_type = 'view' THEN 1 ELSE 0 END) as total_views,
        SUM(CASE WHEN t.interaction_type = 'email_open' THEN 1 ELSE 0 END) as total_email_opens,
        SUM(CASE WHEN t.interaction_type = 'email_click' THEN 1 ELSE 0 END) as total_email_clicks,
        SUM(CASE WHEN t.interaction_type = 'social_engagement' THEN 1 ELSE 0 END) as total_social_engagements,
        
        -- Time-based metrics
        MIN(t.touchpoint_date) as first_touchpoint_date,
        MAX(t.touchpoint_date) as last_touchpoint_date,
        DATEDIFF(day, MIN(t.touchpoint_date), MAX(t.touchpoint_date)) as touchpoint_span_days
        
    FROM touchpoints t
    GROUP BY t.campaign_id
),

conversion_metrics AS (
    -- Conversion and revenue metrics
    SELECT 
        t.campaign_id,
        COUNT(DISTINCT CASE WHEN t.conversion_flag = 1 THEN t.customer_id END) as unique_conversions,
        SUM(CASE WHEN t.conversion_flag = 1 THEN 1 ELSE 0 END) as total_conversions,
        SUM(CASE WHEN t.conversion_flag = 1 THEN t.revenue ELSE 0 END) as total_conversion_revenue,
        AVG(CASE WHEN t.conversion_flag = 1 THEN t.revenue ELSE NULL END) as avg_revenue_per_conversion,
        
        -- Conversion timing
        AVG(CASE WHEN t.conversion_flag = 1 THEN 
            DATEDIFF(day, c.start_date, t.touchpoint_date) 
        END) as avg_days_to_conversion,
        
        MIN(CASE WHEN t.conversion_flag = 1 THEN t.touchpoint_date END) as first_conversion_date,
        MAX(CASE WHEN t.conversion_flag = 1 THEN t.touchpoint_date END) as last_conversion_date
        
    FROM touchpoints t
    JOIN campaigns c ON t.campaign_id = c.campaign_id
    GROUP BY t.campaign_id
),

attribution_metrics AS (
    -- Multi-touch attribution analysis
    SELECT 
        t.campaign_id,
        COUNT(DISTINCT t.customer_id) as total_customers,
        
        -- First-touch attribution
        COUNT(DISTINCT CASE 
            WHEN t.touchpoint_sequence = 1 AND t.conversion_flag = 1 
            THEN t.customer_id 
        END) as first_touch_conversions,
        
        -- Last-touch attribution
        COUNT(DISTINCT CASE 
            WHEN t.is_last_touch = 1 AND t.conversion_flag = 1 
            THEN t.customer_id 
        END) as last_touch_conversions,
        
        -- Multi-touch attribution (weighted)
        SUM(CASE WHEN t.conversion_flag = 1 THEN t.attribution_weight ELSE 0 END) as weighted_conversions,
        
        -- Touchpoint distribution
        AVG(t.touchpoint_sequence) as avg_touchpoint_sequence,
        MAX(t.touchpoint_sequence) as max_touchpoint_sequence,
        
        -- Attribution revenue
        SUM(CASE WHEN t.conversion_flag = 1 THEN t.revenue * t.attribution_weight ELSE 0 END) as attributed_revenue
        
    FROM touchpoints t
    GROUP BY t.campaign_id
),

performance_calculations AS (
    -- Performance calculations and KPIs
    SELECT 
        cbm.*,
        tm.unique_customers_reached,
        tm.total_touchpoints,
        tm.total_touchpoint_cost,
        tm.avg_cost_per_touchpoint,
        tm.total_clicks,
        tm.total_views,
        tm.total_email_opens,
        tm.total_email_clicks,
        tm.total_social_engagements,
        tm.first_touchpoint_date,
        tm.last_touchpoint_date,
        tm.touchpoint_span_days,
        
        cm.unique_conversions,
        cm.total_conversions,
        cm.total_conversion_revenue,
        cm.avg_revenue_per_conversion,
        cm.avg_days_to_conversion,
        cm.first_conversion_date,
        cm.last_conversion_date,
        
        am.total_customers,
        am.first_touch_conversions,
        am.last_touch_conversions,
        am.weighted_conversions,
        am.avg_touchpoint_sequence,
        am.max_touchpoint_sequence,
        am.attributed_revenue,
        
        -- Basic performance metrics
        cm.total_conversions / NULLIF(tm.unique_customers_reached, 0) as conversion_rate,
        cm.total_conversion_revenue / NULLIF(tm.unique_customers_reached, 0) as revenue_per_customer_reached,
        cm.total_conversion_revenue / NULLIF(cm.total_conversions, 0) as revenue_per_conversion,
        tm.total_touchpoint_cost / NULLIF(cm.total_conversions, 0) as cost_per_acquisition,
        tm.total_touchpoint_cost / NULLIF(tm.unique_customers_reached, 0) as cost_per_customer_reached,
        
        -- ROI calculations
        (cm.total_conversion_revenue - tm.total_touchpoint_cost) as net_profit,
        (cm.total_conversion_revenue - tm.total_touchpoint_cost) / NULLIF(tm.total_touchpoint_cost, 0) as roi,
        cm.total_conversion_revenue / NULLIF(tm.total_touchpoint_cost, 0) as revenue_roi,
        
        -- Engagement metrics
        tm.total_clicks / NULLIF(tm.total_views, 0) as click_through_rate,
        tm.total_email_clicks / NULLIF(tm.total_email_opens, 0) as email_click_through_rate,
        tm.total_social_engagements / NULLIF(tm.unique_customers_reached, 0) as social_engagement_rate,
        
        -- Efficiency metrics
        tm.total_touchpoints / NULLIF(tm.unique_customers_reached, 0) as touchpoints_per_customer,
        cm.total_conversions / NULLIF(tm.total_touchpoints, 0) as conversion_per_touchpoint,
        tm.unique_customers_reached / NULLIF(cbm.campaign_duration_days, 0) as customers_reached_per_day,
        cm.total_conversions / NULLIF(cbm.campaign_duration_days, 0) as conversions_per_day,
        
        -- Attribution metrics
        am.first_touch_conversions / NULLIF(am.total_customers, 0) as first_touch_attribution_rate,
        am.last_touch_conversions / NULLIF(am.total_customers, 0) as last_touch_attribution_rate,
        am.weighted_conversions / NULLIF(am.total_customers, 0) as weighted_attribution_rate,
        am.attributed_revenue / NULLIF(cm.total_conversion_revenue, 0) as attribution_revenue_share
        
    FROM campaign_base_metrics cbm
    LEFT JOIN touchpoint_metrics tm ON cbm.campaign_id = tm.campaign_id
    LEFT JOIN conversion_metrics cm ON cbm.campaign_id = cm.campaign_id
    LEFT JOIN attribution_metrics am ON cbm.campaign_id = am.campaign_id
),

channel_performance AS (
    -- Channel-level performance analysis
    SELECT 
        channel,
        COUNT(*) as total_campaigns,
        SUM(budget) as total_channel_budget,
        SUM(total_touchpoint_cost) as total_channel_spend,
        SUM(unique_customers_reached) as total_channel_reach,
        SUM(total_conversions) as total_channel_conversions,
        SUM(total_conversion_revenue) as total_channel_revenue,
        
        -- Channel averages
        AVG(conversion_rate) as avg_channel_conversion_rate,
        AVG(roi) as avg_channel_roi,
        AVG(cost_per_acquisition) as avg_channel_cpa,
        AVG(revenue_per_customer_reached) as avg_channel_rpc,
        
        -- Channel efficiency
        SUM(total_conversion_revenue) / NULLIF(SUM(total_touchpoint_cost), 0) as channel_roi,
        SUM(total_conversions) / NULLIF(SUM(unique_customers_reached), 0) as channel_conversion_rate,
        SUM(total_touchpoint_cost) / NULLIF(SUM(total_conversions), 0) as channel_cpa
        
    FROM performance_calculations
    GROUP BY channel
),

campaign_rankings AS (
    -- Campaign performance rankings
    SELECT 
        *,
        -- Overall performance ranking
        RANK() OVER (ORDER BY roi DESC) as roi_rank,
        RANK() OVER (ORDER BY conversion_rate DESC) as conversion_rank,
        RANK() OVER (ORDER BY cost_per_acquisition ASC) as cpa_rank,
        RANK() OVER (ORDER BY revenue_per_customer_reached DESC) as rpc_rank,
        
        -- Channel-specific rankings
        RANK() OVER (PARTITION BY channel ORDER BY roi DESC) as channel_roi_rank,
        RANK() OVER (PARTITION BY channel ORDER BY conversion_rate DESC) as channel_conversion_rank,
        RANK() OVER (PARTITION BY channel ORDER BY cost_per_acquisition ASC) as channel_cpa_rank,
        
        -- Performance categories
        CASE 
            WHEN roi >= 3 THEN 'Excellent'
            WHEN roi >= 2 THEN 'Good'
            WHEN roi >= 1 THEN 'Average'
            ELSE 'Poor'
        END as roi_performance_category,
        
        CASE 
            WHEN conversion_rate >= 0.05 THEN 'High'
            WHEN conversion_rate >= 0.02 THEN 'Medium'
            ELSE 'Low'
        END as conversion_performance_category,
        
        CASE 
            WHEN cost_per_acquisition <= 50 THEN 'Low'
            WHEN cost_per_acquisition <= 100 THEN 'Medium'
            ELSE 'High'
        END as cpa_performance_category
        
    FROM performance_calculations
)

-- Final comprehensive campaign performance output
SELECT 
    cr.*,
    cp.total_campaigns as channel_total_campaigns,
    cp.total_channel_budget,
    cp.total_channel_spend,
    cp.total_channel_reach,
    cp.total_channel_conversions,
    cp.total_channel_revenue,
    cp.avg_channel_conversion_rate,
    cp.avg_channel_roi,
    cp.avg_channel_cpa,
    cp.avg_channel_rpc,
    cp.channel_roi as channel_overall_roi,
    cp.channel_conversion_rate as channel_overall_conversion_rate,
    cp.channel_cpa as channel_overall_cpa,
    
    -- Performance vs channel benchmarks
    cr.conversion_rate - cp.avg_channel_conversion_rate as conversion_rate_vs_channel,
    cr.roi - cp.avg_channel_roi as roi_vs_channel,
    cr.cost_per_acquisition - cp.avg_channel_cpa as cpa_vs_channel,
    cr.revenue_per_customer_reached - cp.avg_channel_rpc as rpc_vs_channel,
    
    -- Performance indicators
    CASE 
        WHEN cr.conversion_rate > cp.avg_channel_conversion_rate THEN 'Above Average'
        WHEN cr.conversion_rate < cp.avg_channel_conversion_rate THEN 'Below Average'
        ELSE 'Average'
    END as conversion_vs_channel_performance,
    
    CASE 
        WHEN cr.roi > cp.avg_channel_roi THEN 'Above Average'
        WHEN cr.roi < cp.avg_channel_roi THEN 'Below Average'
        ELSE 'Average'
    END as roi_vs_channel_performance,
    
    -- Analysis timestamp
    GETDATE() as analysis_timestamp

FROM campaign_rankings cr
LEFT JOIN channel_performance cp ON cr.channel = cp.channel
ORDER BY cr.roi DESC, cr.conversion_rate DESC;
