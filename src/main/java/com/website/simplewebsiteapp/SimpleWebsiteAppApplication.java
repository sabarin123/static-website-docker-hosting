package com.website.simplewebsiteapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SimpleWebsiteAppApplication {

	public static void main(String[] args) {

		SpringApplication.run(SimpleWebsiteAppApplication.class, args);

		System.out.println("Simple website app started");
	}

}
