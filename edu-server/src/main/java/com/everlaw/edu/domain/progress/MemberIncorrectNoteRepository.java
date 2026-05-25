package com.everlaw.edu.domain.progress;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MemberIncorrectNoteRepository extends JpaRepository<MemberIncorrectNote, Long> {
    
    List<MemberIncorrectNote> findByMemberIdAndIsArchivedFalseAndIsDeletedFalse(Long memberId);
    
    java.util.Optional<MemberIncorrectNote> findByMemberIdAndQuizBankIdAndIsArchivedFalseAndIsDeletedFalse(Long memberId, Long quizBankId);
    
    @Modifying
    @Query("UPDATE MemberIncorrectNote m SET m.isArchived = true WHERE m.member.id = :memberId AND m.lawReference = :lawReference AND m.isArchived = false")
    void archiveByMemberIdAndLawReference(@Param("memberId") Long memberId, @Param("lawReference") String lawReference);
}
