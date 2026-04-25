/*
  Warnings:

  - You are about to drop the column `lecturer` on the `Course` table. All the data in the column will be lost.
  - You are about to drop the column `dateFrom` on the `LeaveRequest` table. All the data in the column will be lost.
  - You are about to drop the column `dateTo` on the `LeaveRequest` table. All the data in the column will be lost.
  - You are about to drop the `Task` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `lecturerId` to the `Course` table without a default value. This is not possible if the table is not empty.
  - Added the required column `courseId` to the `LeaveRequest` table without a default value. This is not possible if the table is not empty.
  - Added the required column `date` to the `LeaveRequest` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE `Task` DROP FOREIGN KEY `Task_studentId_fkey`;

-- AlterTable
ALTER TABLE `Attendance` ADD COLUMN `faceVerified` BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE `Course` DROP COLUMN `lecturer`,
    ADD COLUMN `lecturerId` VARCHAR(191) NOT NULL;

-- AlterTable
ALTER TABLE `LeaveRequest` DROP COLUMN `dateFrom`,
    DROP COLUMN `dateTo`,
    ADD COLUMN `courseId` VARCHAR(191) NOT NULL,
    ADD COLUMN `date` DATETIME(3) NOT NULL,
    ADD COLUMN `reviewNote` TEXT NULL,
    ADD COLUMN `reviewedAt` DATETIME(3) NULL,
    ADD COLUMN `reviewedById` VARCHAR(191) NULL;

-- AlterTable
ALTER TABLE `Schedule` MODIFY `dayOfWeek` ENUM('Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu') NOT NULL;

-- DropTable
DROP TABLE `Task`;

-- CreateTable
CREATE TABLE `Lecturer` (
    `id` VARCHAR(191) NOT NULL,
    `lecturerId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `email` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NULL,
    `department` VARCHAR(191) NOT NULL,
    `faculty` VARCHAR(191) NOT NULL,
    `password` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `Lecturer_lecturerId_key`(`lecturerId`),
    UNIQUE INDEX `Lecturer_email_key`(`email`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `Course` ADD CONSTRAINT `Course_lecturerId_fkey` FOREIGN KEY (`lecturerId`) REFERENCES `Lecturer`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `LeaveRequest` ADD CONSTRAINT `LeaveRequest_courseId_fkey` FOREIGN KEY (`courseId`) REFERENCES `Course`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `LeaveRequest` ADD CONSTRAINT `LeaveRequest_reviewedById_fkey` FOREIGN KEY (`reviewedById`) REFERENCES `Lecturer`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
