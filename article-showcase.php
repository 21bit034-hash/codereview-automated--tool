<?php
/**
 * Plugin Name: Article Showcase
 * Plugin URI:  http://code-review.in
 * Description: Shows latest articles on the homepage.
 * Version:     1.0.0
 * Author:      Your Name
 * License:     GPL2
 *
 * @package Article_Showcase
 */

// Exit if accessed directly.
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// Shortcode to display articles.
/**
 * Display articles in a grid layout.
 *
 * @return string HTML output of articles.
 */
function article_showcase_display() {
	$args = array(
		'post_type'      => 'post',
		'posts_per_page' => 6,
		'post_status'    => 'publish',
	);

	$query  = new WP_Query( $args );
	$output = '';

	if ( $query->have_posts() ) {
		$output .= '<div class="article-showcase">';

		while ( $query->have_posts() ) {
			$query->the_post();
			$output .= '<div class="article-card">';
			$output .= '<h2><a href="' . esc_url( get_permalink() ) . '">' . esc_html( get_the_title() ) . '</a></h2>';
			$output .= '<p>' . esc_html( get_the_excerpt() ) . '</p>';
			$output .= '<a href="' . esc_url( get_permalink() ) . '">Read More</a>';
			$output .= '</div>';
		}

		$output .= '</div>';
		wp_reset_postdata();
	} else {
		$output .= '<p>No articles found.</p>';
	}

	return $output;
}
add_shortcode( 'article_showcase', 'article_showcase_display' );
